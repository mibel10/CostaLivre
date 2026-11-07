shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float tile=mod(floor(p.x*0.7)+floor(p.z*0.7),2.0);
 float vein=pow(abs(sin(p.x*4.0+sin(p.z*2.0)*2.0)),18.0);
 ALBEDO=mix(vec3(0.18,0.24,0.23),vec3(0.32,0.36,0.32),tile)+vein*0.05;
 ROUGHNESS=0.38; METALLIC=0.12;
}
