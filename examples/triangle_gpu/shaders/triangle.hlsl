struct VertexOutput {
    float4 position : SV_Position;
    float4 color : TEXCOORD0;
};

VertexOutput vertex_main(uint vertex_id : SV_VertexID) {
    const float2 positions[3] = {
        float2(0.0, -0.7),
        float2(-0.7, 0.7),
        float2(0.7, 0.7)
    };
    const float4 colors[3] = {
        float4(1.0, 0.1, 0.1, 1.0),
        float4(0.1, 1.0, 0.2, 1.0),
        float4(0.1, 0.3, 1.0, 1.0)
    };
    VertexOutput output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    output.color = colors[vertex_id];
    return output;
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    return input.color;
}
