
struct SPRITE_VERTEX_DATA {
    // TOTAL = 16   USED = 8   WASTE = 8 (%50.00)
    float2 texture_uv; // off    0  size    8
    uint2 __pad__0;    // off    8  size    8
};
StructuredBuffer<SPRITE_VERTEX_DATA> SPRITE_VERTEX_DATA_BUFFER : register(t0, space0);

cbuffer GLOBAL : register(b0, space1) {
    // TOTAL = 16   USED = 8   WASTE = 8 (%50.00)
    float2 pos_offset; // off    0  size    8
    uint2 __pad__0;    // off    8  size    8
};

struct vertex_in_PACKED {
    float3 in_loc0 : TEXCOORD0; // slot 0, off   0, arange _3_1
    uint2  in_loc1 : TEXCOORD1; // slot 1, off   0, arange _1_1_1_1
};

struct vertex_in {
    float3 position; // off   0 (slot 0, contract: VERTEX_POSITIONS)
    uint sprite_id; // off   0 (slot 1, contract: SPRITE_VERTEX_INDEXES)
    uint sprite_vertex; // off   4 (slot 1, contract: SPRITE_VERTEX_INDEXES)
};

vertex_in unpack_vertex_input(vertex_in_PACKED pck) {
    vertex_in v;
    v.position = pck.in_loc0.xyz;
    v.sprite_id = pck.in_loc1.x;
    v.sprite_vertex = pck.in_loc1.y;
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
    vert_out.vert_pos = float4(vert_in.position, 1.0f);
    uint sprite_tex_pos_index = (vert_in.sprite_id * 4) + vert_in.sprite_vertex;
    SPRITE_VERTEX_DATA sprite_tex_pos = SPRITE_VERTEX_DATA_BUFFER[sprite_tex_pos_index];
    vert_out.tex_pos = sprite_tex_pos.texture_uv;
    return pack_vertex_output(vert_out);
}