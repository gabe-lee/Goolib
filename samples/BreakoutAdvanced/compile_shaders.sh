
shadercross vert_MAIN_VERTEX_SHADER.hlsl -s HLSL -d DXIL -t vertex -e "main" -o vert_MAIN_VERTEX_SHADER.dxil
shadercross vert_MAIN_VERTEX_SHADER.hlsl -s HLSL -d MSL -t vertex -e "main" -o vert_MAIN_VERTEX_SHADER.msl
shadercross vert_MAIN_VERTEX_SHADER.hlsl -s HLSL -d SPIRV -t vertex -e "main" -o vert_MAIN_VERTEX_SHADER.spv
shadercross frag_MAIN_FRAGMENT_SHADER.hlsl -s HLSL -d DXIL -t fragment -e "main" -o frag_MAIN_FRAGMENT_SHADER.dxil
shadercross frag_MAIN_FRAGMENT_SHADER.hlsl -s HLSL -d MSL -t fragment -e "main" -o frag_MAIN_FRAGMENT_SHADER.msl
shadercross frag_MAIN_FRAGMENT_SHADER.hlsl -s HLSL -d SPIRV -t fragment -e "main" -o frag_MAIN_FRAGMENT_SHADER.spv