struct vert_to_frag {
    float4 vert_pos;
    float2 tex_pos;
};

struct vert_to_frag_PACKED {
    float4 reg0 : SV_Position;
    float2 reg1 : TEXCOORD0;
};

vert_to_frag unpack_frag_input(vert_to_frag_PACKED pck) {
    vert_to_frag vf;
    vf.vert_pos = pck.reg0;
    vf.tex_pos = pck.reg1.xy;
    return vf;
}
struct fragment_out {
    float4 color; // target 0 [.xyzw]
};

struct frag_out_PACKED {
    float4 target0 : SV_Target0; // comps 4
};

frag_out_PACKED pack_fragment_output(fragment_out f) {
    frag_out_PACKED pck;
    pck.target0 = f.color;
    return pck;
}
frag_out_PACKED main(vert_to_frag_PACKED pck) {
    vert_to_frag frag_in = unpack_frag_input(pck);
    fragment_out frag_out;
    frag_out.color = float4(1.0, 1.0, 1.0, 1.0);
    return pack_fragment_output(frag_out);
}