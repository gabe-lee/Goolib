struct SPRITE_VERTEX_DATA {
    // TOTAL = 16   USED = 8   WASTE = 8 (%50.00)
    float2 texture_uv; // off    0  size    8
    uint2 __pad__0;    // off    8  size    8
};
StructuredBuffer<SPRITE_VERTEX_DATA> SPRITE_VERTEX_DATA_BUFFER : register(t0, space0);

cbuffer WINDOW_RENDER_INFO : register(b0, space1) {
    // TOTAL = 16   USED = 16   WASTE = 0 (% 0.00)
    float2 camera_offset; // off    0  size    8
    float2 target_size;   // off    8  size    8
};

struct vertex_in_PACKED {
    float2 in_loc0 : TEXCOORD0; // slot 0, off   0, arange _2_2
    uint   in_loc1 : TEXCOORD1; // slot 1, off   0, arange _1_1_1_1
};

struct vertex_in {
    float2 position; // off   0 (slot 0, contract: VERTEX_POSITIONS)
    uint sprite_vertex; // off   0 (slot 1, contract: SPRITE_VERTEX_INDEXES)
};

vertex_in unpack_vertex_input(vertex_in_PACKED pck) {
    vertex_in v;
    v.position = pck.in_loc0.xy;
    v.sprite_vertex = pck.in_loc1.x;
    return v;
}
struct vert_to_frag {
    float4 vert_pos;
    float2 tex_pos;
};

struct vert_to_frag_PACKED {
    float4 reg0 : SV_Position;
    linear noperspective float2 reg1 : TEXCOORD0;
};

vert_to_frag_PACKED pack_vertex_output(vert_to_frag vf) {
    vert_to_frag_PACKED pck;
    pck.reg0.xyzw = vf.vert_pos;
    pck.reg1.xy = vf.tex_pos;
    return pck;
}

vert_to_frag_PACKED main(vertex_in_PACKED pck) {
    vertex_in vert_in = unpack_vertex_input(pck);
    vert_to_frag vert_out;
    float2 viewport_pos = vert_in.position - camera_offset;
    float2 ndc_pos = ((viewport_pos / target_size) * 2.0f) - 1.0f;
    vert_out.vert_pos = float4(ndc_pos, 0.0f, 1.0f);
    SPRITE_VERTEX_DATA sprite_tex_pos = SPRITE_VERTEX_DATA_BUFFER[vert_in.sprite_vertex];
    vert_out.tex_pos = sprite_tex_pos.texture_uv;
    return pack_vertex_output(vert_out);
}

// vert_to_frag_PACKED main(uint vert_id : SV_VertexID) {
//     vert_to_frag_PACKED pck;
    
//     // Generate a fullscreen triangle purely from the vertex ID (0, 1, 2)
//     float2 grid = float2((vert_id << 1) & 2, vert_id & 2);
//     pck.reg0 = float4(grid * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
//     pck.reg1 = float2(0.0f, 0.0f);
//     return pck;
// }