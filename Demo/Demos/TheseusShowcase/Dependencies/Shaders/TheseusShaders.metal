#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types (must match ShaderTypes.swift)

struct GaussianBlurParams {
    float2 texelSize;
    int blurRadius;
    int padding;
};

struct BlendPassParams {
    float2 viewSize;     // 8 bytes, aligned to 8
    float cornerRadius;  // 4 bytes
    float opacity;       // 4 bytes
    float2 shapePadding; // 8 bytes - inset from edges
};   // Total: 24 bytes

struct GlassParams {
    float2 viewSize;      // 8 bytes
    float cornerRadius;   // 4 bytes
    float opacity;        // 4 bytes
    float edgeWidth;      // 4 bytes (refraction edge thickness)
    float iorFactor;      // 4 bytes (index of refraction factor)
    float rimRange;       // 4 bytes (rim glow range)
    float rimGlow;        // 4 bytes (rim glow intensity)
    float rimCurve;       // 4 bytes (rim glow curve)
    // Specular parameters
    float specularRange;     // 4 bytes
    float specularIntensity; // 4 bytes
    float specularFocus;     // 4 bytes
    float specularConvergence; // 4 bytes
    float lightAngle;     // 4 bytes
    float oppositeFalloff; // 4 bytes
    // Chromatic and tint
    float chromaticSpread;  // 4 bytes (chromatic aberration)
    float mirrorMode;     // 4 bytes (0.0 = lens, 1.0 = mirror)
    float2 stretchScale;  // 8 bytes - morph/stretch scale
    float2 shapePadding;  // 8 bytes - inset from edges
    float4 tint;          // 16 bytes
    float4 farSpecularColor;  // 16 bytes - specular color on far side
    float4 nearSpecularColor; // 16 bytes - specular color on near side
};   // Total: 128 bytes

// Shadow pass parameters
struct ShadowParams {
    float2 viewSize;      // 8 bytes
    float cornerRadius;   // 4 bytes
    float padding1;       // 4 bytes (alignment)
    float2 shapePadding;  // 8 bytes
    float2 stretchScale;  // 8 bytes
};   // Total: 32 bytes

// Constants
constant float PI = 3.14159265359;

// Chromatic aberration spread (single value approach)
constant float CHROMATIC_SPREAD = 0.032;

// Rim/edge glow constants (reformulated Fresnel)
constant float RIM_BASE = 0.035;
constant float RIM_SCALE = 0.965;  // 1.0 - RIM_BASE

// Edge reflection parameters
constant float REFLECTION_POWER = 30.0;
constant float2 LIGHT_VECTOR = float2(0.7071, -0.7071);

// Outer glow parameters
constant float OUTER_GLOW_STRENGTH = 0.22;
constant float OUTER_GLOW_SPREAD = 6.0;
constant float OUTER_GLOW_FALLOFF = 0.85;
constant float3 GLOW_TINT = float3(0.0);
constant float2 GLOW_BIAS = float2(0.0, 1.0);
constant float GLOW_FOCUS = 1.0;

// Inner vignette parameters
constant float INNER_VIGNETTE_STRENGTH = 0.15;
constant float INNER_VIGNETTE_SPREAD = 20.0;
constant float INNER_VIGNETTE_FALLOFF = 1.0;
constant float2 INNER_VIGNETTE_BIAS = float2(0.0, -1.0);

// Convert 2D vector to angle (0 to 2*PI)
float vec2ToAngle(float2 v) {
    float angle = atan2(v.y, v.x);
    if (angle < 0.0) angle += 2.0 * PI;
    return angle;
}

// Fast power-of-5 for Fresnel term
inline float fresnelPow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

// Rim intensity based on viewing angle
// Uses reformulated Schlick: base + scale * (1 - cos)^5
float rimIntensity(float2 normal, float2 viewDir) {
    float cosTheta = max(dot(normalize(normal), normalize(viewDir)), 0.0);
    return RIM_BASE + RIM_SCALE * fresnelPow5(1.0 - cosTheta);
}

// Edge reflection highlight using half-angle method
float edgeReflection(float2 normal, float2 viewDir) {
    float2 lightDir = normalize(LIGHT_VECTOR);
    float2 halfVec = normalize(lightDir + normalize(viewDir));
    float NdotH = max(dot(normalize(normal), halfVec), 0.0);
    return pow(NdotH, REFLECTION_POWER);
}

struct QuadVertex {
    float2 position;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Vertex Shader

vertex VertexOut vertexPassthrough(
    uint vertexID [[vertex_id]],
    constant QuadVertex* vertices [[buffer(0)]]
) {
    VertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

// MARK: - Horizontal Gaussian Blur

fragment half4 gaussianBlurHorizontal(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> srcTexture [[texture(0)]],
    constant GaussianBlurParams& params [[buffer(0)]],
    constant float* weights [[buffer(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Center sample
    half4 color = srcTexture.sample(textureSampler, in.texCoord) * half(weights[0]);

    // Symmetric samples left and right
    for (int i = 1; i <= params.blurRadius; ++i) {
        half w = half(weights[i]);
        float offsetX = float(i) * params.texelSize.x;

        color += srcTexture.sample(textureSampler, in.texCoord + float2(offsetX, 0.0)) * w;
        color += srcTexture.sample(textureSampler, in.texCoord - float2(offsetX, 0.0)) * w;
    }

    return color;
}

// MARK: - Vertical Gaussian Blur

fragment half4 gaussianBlurVertical(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> srcTexture [[texture(0)]],
    constant GaussianBlurParams& params [[buffer(0)]],
    constant float* weights [[buffer(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Center sample
    half4 color = srcTexture.sample(textureSampler, in.texCoord) * half(weights[0]);

    // Symmetric samples up and down
    for (int i = 1; i <= params.blurRadius; ++i) {
        half w = half(weights[i]);
        float offsetY = float(i) * params.texelSize.y;

        color += srcTexture.sample(textureSampler, in.texCoord + float2(0.0, offsetY)) * w;
        color += srcTexture.sample(textureSampler, in.texCoord - float2(0.0, offsetY)) * w;
    }

    return color;
}

// Edge normal multiplier for refraction calculations
constant float EDGE_NORMAL_MULTIPLIER = 1350.0;

// MARK: - Shape Distance Functions

// Signed distance for rounded rectangle (uv-center formulation)
float shapeDistance(float2 uv, float2 center, float2 halfSize, float r) {
    float2 q = abs(uv - center) - (halfSize - float2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Gradient/normal of rounded rectangle - direction away from edge
float2 shapeGradient(float2 uv, float2 center, float2 halfSize, float r) {
    float2 p = uv - center;
    float2 q = abs(p) - (halfSize - float2(r));
    float2 signP = sign(p);

    float2 grad;
    if (q.x > 0.0 && q.y > 0.0) {
        // Corner arc region
        float len = length(q);
        grad = (len > 0.0001) ? (q / len) : float2(0.7071, 0.7071);
        grad *= signP;
    } else if (q.x > q.y) {
        // Side edge region
        grad = float2(signP.x, 0.0);
    } else {
        // Top/bottom edge region
        grad = float2(0.0, signP.y);
    }

    return grad;
}

// MARK: - Blend Pass (Final Output with Corner Radius)

fragment half4 blendPassFragment(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> blurredTexture [[texture(0)]],
    constant BlendPassParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    half4 color = blurredTexture.sample(textureSampler, in.texCoord);

    // Apply corner radius mask with directional glow/vignette
    if (params.cornerRadius > 0.0) {
        // Convert UV to pixel coordinates
        float2 pixelPos = in.texCoord * params.viewSize;
        float2 center = params.viewSize * 0.5;

        // Calculate shape distance (with padding inset)
        float2 halfSize = center - params.shapePadding;
        float dist = shapeDistance(pixelPos, center, halfSize, params.cornerRadius);

        if (dist < -INNER_VIGNETTE_SPREAD) {
            // Deep inside shape - no vignette, keep full opacity

        } else if (dist < 0.0) {
            // Inside shape within inner vignette range
            float innerDist = -dist;

            // Get gradient (direction away from shape edge)
            float2 grad = shapeGradient(pixelPos, center, halfSize, params.cornerRadius);

            // Calculate directional factor: alignment with vignette direction
            float2 vignetteDir = normalize(INNER_VIGNETTE_BIAS);
            float dirFactor = dot(grad, vignetteDir);
            dirFactor = clamp(pow(max(0.0, dirFactor), GLOW_FOCUS), 0.0, 1.0);

            // Inner vignette zone - fade from edge inward
            float vignetteFactor = 1.0 - smoothstep(0.0, INNER_VIGNETTE_SPREAD * INNER_VIGNETTE_FALLOFF, innerDist);
            vignetteFactor *= INNER_VIGNETTE_STRENGTH * dirFactor;

            // Blend vignette with existing color
            if (vignetteFactor > 0.001) {
                color.rgb = mix(color.rgb, half3(GLOW_TINT), half(vignetteFactor));
            }

        } else if (dist < OUTER_GLOW_SPREAD) {
            // Outer glow zone
            float2 grad = shapeGradient(pixelPos, center, halfSize, params.cornerRadius);

            // Calculate directional factor
            float2 glowDir = normalize(GLOW_BIAS);
            float dirFactor = dot(grad, glowDir);
            dirFactor = clamp(pow(max(0.0, dirFactor), GLOW_FOCUS), 0.0, 1.0);

            // Glow zone - fade from glow to transparent
            float glowFactor = 1.0 - smoothstep(0.0, OUTER_GLOW_SPREAD * OUTER_GLOW_FALLOFF, dist);
            glowFactor *= OUTER_GLOW_STRENGTH * dirFactor;

            if (glowFactor > 0.001) {
                color.rgb = half3(GLOW_TINT);
                color.a = half(glowFactor);
            } else {
                color.a = 0.0;
            }
        } else {
            // Outside glow - fully transparent
            color.a = 0.0;
        }
    }

    // Apply overall opacity
    color.a *= half(params.opacity);

    return color;
}

// MARK: - Shadow Pass

fragment half4 shadowPassFragment(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> blurredTexture [[texture(0)]],
    constant ShadowParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Sample the blurred texture
    half4 color = blurredTexture.sample(textureSampler, in.texCoord);

    // Convert UV to pixel coordinates
    float2 pixelPos = in.texCoord * params.viewSize;
    float2 center = params.viewSize * 0.5;
    float2 halfSize = center - params.shapePadding;
    float2 scaledPixelPos = pixelPos / params.stretchScale;
    float2 scaledCenter = center / params.stretchScale;

    // Calculate shape distance
    float dist = shapeDistance(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius);

    // Apply inner vignette only if within range
    if (dist >= -INNER_VIGNETTE_SPREAD && dist < 0.0) {
        float innerDist = -dist;
        float2 grad = shapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius);

        // Calculate directional factor: vignette at top
        float2 vignetteDir = normalize(INNER_VIGNETTE_BIAS);
        float dirFactor = dot(grad, vignetteDir);
        dirFactor = clamp(pow(max(0.0, dirFactor), GLOW_FOCUS), 0.0, 1.0);

        // Inner vignette zone - fade from edge inward
        float vignetteFactor = 1.0 - smoothstep(0.0, INNER_VIGNETTE_SPREAD * INNER_VIGNETTE_FALLOFF, innerDist);
        vignetteFactor *= INNER_VIGNETTE_STRENGTH * dirFactor;

        if (vignetteFactor > 0.001) {
            color.rgb = mix(color.rgb, half3(GLOW_TINT), half(vignetteFactor));
        }
    }

    return color;
}

// MARK: - Glass Rendering

// Sample texture with chromatic aberration (single spread approach)
// Creates rainbow iridescence effect at edges through wavelength-based offsets
half4 sampleWithAberration(
    texture2d<half, access::sample> tex,
    sampler s,
    float2 baseUV,
    float2 offset,
    float aberrationFactor
) {
    // Per-channel sampling with spread-based offset adjustment
    // Red wavelengths: less offset (1 + spread), Blue: more offset (1 - spread)
    float spread = CHROMATIC_SPREAD * aberrationFactor;
    half4 pixel = half4(1.0h);
    pixel.r = tex.sample(s, baseUV + offset * (1.0 + spread)).r;
    pixel.g = tex.sample(s, baseUV + offset).g;
    pixel.b = tex.sample(s, baseUV + offset * (1.0 - spread)).b;
    return pixel;
}

fragment half4 glassRenderFragment(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> blurredTexture [[texture(0)]],
    texture2d<half, access::sample> sourceTexture [[texture(1)]],
    constant GlassParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Convert UV to pixel coordinates
    float2 pixelPos = in.texCoord * params.viewSize;
    float2 center = params.viewSize * 0.5;
    float2 halfSize = center - params.shapePadding;

    // Apply stretch scale for shape distortion
    float2 scaledPixelPos = pixelPos / params.stretchScale;
    float2 scaledCenter = center / params.stretchScale;

    // Calculate shape distance (negative = inside)
    float dist = shapeDistance(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius);

    half4 color;

    if (dist < 0.0) {
        // Inside shape
        float nDist = -dist;  // positive distance inside

        // CENTER ZONE: Pure pass-through with NO effects
        if (nDist >= params.edgeWidth) {
            color = sourceTexture.sample(textureSampler, in.texCoord);
        } else {
            // EDGE ZONE: Apply refraction, blur, tint, rim, specular effects
            float2 normal = shapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius) * EDGE_NORMAL_MULTIPLIER;

            // Snell's law approximation for edge transition
            float x_R_ratio = clamp(1.0 - nDist / params.edgeWidth, 0.0, 1.0);
            float thetaI = asin(x_R_ratio * x_R_ratio);
            float sinThetaT = sin(thetaI) / params.iorFactor;
            float thetaT = asin(clamp(sinThetaT, -1.0, 1.0));
            float edgeFactor = -tan(thetaT - thetaI);

            // Calculate rim intensity using view angle
            float2 viewDir = float2(0.0, 1.0);  // Top-down view
            float rim = rimIntensity(normal, viewDir);
            // Modulate by edge proximity for smooth transition
            float rimEdgeFactor = 1.0 - (nDist / params.edgeWidth);
            rim *= rimEdgeFactor * params.rimGlow;

            // Calculate specular geometric factor
            float specRangeScale = pow(500.0 / params.specularRange, 2.0);
            float specGeoBase = 1.0 + (dist * params.viewSize.y / 1500.0) * specRangeScale + params.specularFocus;
            float specGeoFactor = clamp(pow(specGeoBase, 5.0), 0.0, 1.0);

            // Get tint color from params
            half4 tintColor = half4(params.tint);

            // Check if we're in the mirror zone
            if (params.mirrorMode > 0.5) {
                // MIRROR MODE: True mirror effect
                float halfThickness = params.edgeWidth * 0.5;

                if (nDist < halfThickness) {
                    // ZONE 1: Mirror reflection with curved edge effect
                    float2 direction = normalize(normal);

                    // Curved mirror progression
                    float t = nDist / halfThickness;
                    float curvedT = sin(t * PI / 2.0);

                    // Apply curved offset
                    float pixelOffset = params.edgeWidth - 2.0 * curvedT * halfThickness;
                    float2 mirrorOffset = -direction * pixelOffset / params.viewSize * params.iorFactor;

                    // Sample with chromatic aberration
                    color = sampleWithAberration(
                        blurredTexture,
                        textureSampler,
                        in.texCoord,
                        mirrorOffset,
                        params.chromaticSpread
                    );

                } else {
                    // ZONE 2: Beyond fold line - show original blurred content
                    color = blurredTexture.sample(textureSampler, in.texCoord);
                }

            } else {
                // LENS MODE with smooth transition to prevent jitter
                // Blend between refracted (blurred) and source based on edgeFactor
                float2 uvOffset = -normal * max(edgeFactor, 0.0) * 0.05 / params.viewSize.y;

                half4 refractedColor = sampleWithAberration(
                    blurredTexture,
                    textureSampler,
                    in.texCoord,
                    uvOffset,
                    params.chromaticSpread
                );

                half4 sourceColor = sourceTexture.sample(textureSampler, in.texCoord);

                // Smooth blend: full refraction at edgeFactor >= 0.15, full pass-through at edgeFactor <= 0
                float blendFactor = smoothstep(0.0, 0.15, edgeFactor);
                color = mix(sourceColor, refractedColor, half(blendFactor));
            }

            // Smooth effect strength based on edge factor (prevents abrupt effect changes)
            float effectStrength = smoothstep(0.0, 0.15, edgeFactor);
            bool applyEffects = (effectStrength > 0.001) || (params.mirrorMode > 0.5);

            if (applyEffects) {
                // Scale effect intensity by effectStrength for smooth transition
                float scaledEffectStrength = (params.mirrorMode > 0.5) ? 1.0 : effectStrength;

                // Apply tint color (only in edge zone)
                color = mix(color, half4(tintColor.rgb, 1.0h), half(tintColor.a * 0.8 * scaledEffectStrength));

                // Apply rim highlight - brighten existing color (softer than pure white mix)
                half rimHighlight = half(rim * scaledEffectStrength * 0.6);
                color.rgb = color.rgb + rimHighlight * (1.0h - color.rgb);

                // Calculate edge reflection (half-angle method)
                float specular = edgeReflection(normal, viewDir);

                // Modulate by distance from edge (geometric factor) and user settings
                specular *= specGeoFactor * params.specularIntensity;

                // Determine nearside vs farside based on light direction
                float lightDot = dot(normalize(normal), normalize(LIGHT_VECTOR));
                bool isFarside = lightDot < 0.0;

                // Apply opposite side attenuation
                if (isFarside) {
                    specular *= params.oppositeFalloff;
                }

                half4 specularColor = isFarside ? half4(params.farSpecularColor) : half4(params.nearSpecularColor);
                color = mix(color, specularColor, half(specular * scaledEffectStrength));
            }
        }
    } else {
        // Outside shape
        color = blurredTexture.sample(textureSampler, in.texCoord);
    }

    // Apply corner radius mask with outer glow only
    if (params.cornerRadius > 0.0) {
        if (dist < 0.0) {
            // Inside shape - inner vignette already applied in previous pass

        } else if (dist < OUTER_GLOW_SPREAD) {
            // Outer glow zone
            float2 grad = shapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius);

            // Calculate directional factor
            float2 glowDir = normalize(GLOW_BIAS);
            float dirFactor = dot(grad, glowDir);
            dirFactor = clamp(pow(max(0.0, dirFactor), GLOW_FOCUS), 0.0, 1.0);

            // Glow zone - fade to transparent
            float glowFactor = 1.0 - smoothstep(0.0, OUTER_GLOW_SPREAD * OUTER_GLOW_FALLOFF, dist);
            glowFactor *= OUTER_GLOW_STRENGTH * dirFactor;

            if (glowFactor > 0.001) {
                color.rgb = half3(GLOW_TINT);
                color.a = half(glowFactor);
            } else {
                color.a = 0.0;
            }
        } else {
            // Outside glow - fully transparent
            color.a = 0.0;
        }
    }

    // Apply overall opacity
    color.a *= half(params.opacity);

    return color;
}

