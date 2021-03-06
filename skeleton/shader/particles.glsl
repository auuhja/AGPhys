##GL_VERTEX_SHADER

#version 400
layout(location=0) in vec3 in_position;
layout(location=1) in float in_radius;
layout(location=2) in vec4 in_color;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

uniform mat4 MV;
uniform mat4 MVP;

out vec4 color;
out float radius;

void main() {
    gl_Position = view *model* vec4(in_position,1);
    color = vec4(in_color);
    radius = in_radius;
}


##GL_GEOMETRY_SHADER
#version 400

layout(points) in;
in vec4[1] color;
in float[1] radius;
layout(triangle_strip, max_vertices=4) out;
uniform mat4 proj;
uniform mat4 view;

out vec2 tc;
out vec4 color2;
out vec3 lightDir;

void main() {

    vec3 L = normalize(vec3(view*vec4(1,1,1,0)));

    //create a billboard with the given radius
  vec4 pos = gl_in[0].gl_Position;
  vec4 coords = gl_in[0].gl_Position;

  float dx=radius[0];
  float dy=radius[0];

  vec4 ix=vec4(-1,1,-1,1);
  vec4 iy=vec4(-1,-1,1,1);
  vec4 tx=vec4(0,1,0,1);
  vec4 ty=vec4(0,0,1,1);


  for(int i =0; i<4;i++){
      pos.x =ix[i]*dx +coords.x;
      pos.y =iy[i]*dy +coords.y;
      tc.x = tx[i];
      tc.y = ty[i];
      color2 = color[0];
      gl_Position = proj*pos;
      lightDir = L;
      EmitVertex();
  }
}


##GL_FRAGMENT_SHADER

#version 400



in vec4 color2;
in vec2 tc;
in vec3 lightDir;
layout(location=0) out vec4 out_color;

void main() {

    //make the billboard to look like a sphere
    vec2 reltc = tc*2-vec2(1);
    float lensqr = dot(reltc, reltc);
    if(lensqr > 1.0)
        discard;
    vec3 n = vec3(reltc, sqrt(1.0 - lensqr));
    n = normalize(n);

    //complicated lighting model
    float intensity = max(0.1,dot(n,lightDir));

    out_color = intensity*color2;
}

##end
