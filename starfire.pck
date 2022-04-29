GDPC                                                                               <   res://.import/icon.png-487276ed1e3a0c39cad0279d744ee560.stex�m      �      &�y���ڞu;>��.p   res://Scenes/Main.tscn  �      �      t�0�V�N%�gi�v��   res://Scenes/Planet.tscnp      <      ��Ade>u��m7���-   res://Scenes/Player.tscn�$      �       z��M*��T�]B�{<   res://Scenes/Star.tscn  �E      9      D�i������L��ݲ�   res://Scenes/System.tscn�Q             �ֵ�xx��gHT��   res://Scripts/Main.gd.remap �v      '       *�e�R��_�������   res://Scripts/Main.gdc  S      `      �����2��A�ޢ    res://Scripts/Planet.gd.remap   �v      )       AC��V�����}�%�   res://Scripts/Planet.gdcpU      �	      �)O�����T�6�    res://Scripts/Player.gd.remap   �v      )       <y;�9Y;�k��S�   res://Scripts/Player.gdc_      �      Zz��<�yH�&��aN$   res://Scripts/PlayerCamera.gd.remap w      /       O�%�@�r!X�I�I&    res://Scripts/PlayerCamera.gdc  g      .      �z�!���t2YЦ,�"   res://Scripts/Star.gd.remap @w      '       OH�: �NS]���G   res://Scripts/Star.gdc  @i      <      �
Jn�gW� ����    res://Scripts/System.gd.remap   pw      )       L�^���-LP*�I���   res://Scripts/System.gdc�j      �      )^�l��޵��b\��   res://default_env.tres  @m      �       um�`�N��<*ỳ�8   res://icon.png  �w      �      G1?��z�c��vN��   res://icon.png.import   �s      �      ��fe��6�B��^ U�   res://project.binary��      �       Mh��`\5S�d��    [gd_scene load_steps=4 format=2]

[ext_resource path="res://Scenes/Player.tscn" type="PackedScene" id=2]
[ext_resource path="res://Scripts/Main.gd" type="Script" id=4]

[sub_resource type="Environment" id=1]
background_mode = 1
ambient_light_color = Color( 1, 1, 1, 1 )
ambient_light_energy = 0.1
glow_enabled = true
glow_strength = 1.4
glow_blend_mode = 1
glow_high_quality = true

[node name="Main" type="Spatial"]
script = ExtResource( 4 )

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource( 1 )

[node name="Player" parent="." instance=ExtResource( 2 )]
transform = Transform( 0.1, 0, 0, 0, 0.1, 0, 0, 0, 0.1, 0, 0, 0 )
      [gd_scene load_steps=6 format=2]

[ext_resource path="res://Scripts/Planet.gd" type="Script" id=1]

[sub_resource type="SphereMesh" id=1]
radial_segments = 16
rings = 8

[sub_resource type="Shader" id=2]
code = "/*
Realistic Water Shader for Godot 3.4 
Modified to work with Godot 3.4 with thanks to jmarceno.
Copyright (c) 2019 UnionBytes, Achim Menzel (alias AiYori)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- UnionBytes 
-- YouTube: www.youtube.com/user/UnionBytes
*/


// For this shader min. GODOT 3.1.1 is required, because 3.1 has a depth buffer bug!
shader_type 	spatial;
render_mode 	cull_disabled,diffuse_burley,specular_schlick_ggx, blend_mix;


// Wave settings:
uniform float	wave_speed		 = 0.5; // Speed scale for the waves
uniform vec4	wave_a			 = vec4(1.0, 1.0, 0.35, 3.0); 	// xy = Direction, z = Steepness, w = Length
uniform	vec4	wave_b			 = vec4(1.0, 0.6, 0.30, 1.55);	// xy = Direction, z = Steepness, w = Length
uniform	vec4	wave_c			 = vec4(1.0, 1.3, 0.25, 0.9); 	// xy = Direction, z = Steepness, w = Length

// Surface settings:
uniform vec2 	sampler_scale 	 = vec2(0.25, 0.25); 			// Scale for the sampler
uniform vec2	sampler_direction= vec2(0.05, 0.04); 			// Direction and speed for the sampler offset

uniform sampler2D uv_sampler : hint_aniso; 						// UV motion sampler for shifting the normalmap
uniform vec2 	uv_sampler_scale = vec2(0.25, 0.25); 			// UV sampler scale
uniform float 	uv_sampler_strength = 0.04; 					// UV shifting strength

uniform sampler2D normalmap_a_sampler : hint_normal;			// Normalmap sampler A
uniform sampler2D normalmap_b_sampler : hint_normal;			// Normalmap sampler B

uniform sampler2D foam_sampler : hint_black;					// Foam sampler
uniform float 	foam_level 		 = 0.5;							// Foam level -> distance from the object (0.0 - 0.5)

// Volume settings:
uniform float 	refraction 		 = 0.075;						// Refraction of the water

uniform vec4 	color_deep : hint_color;						// Color for deep places in the water, medium to dark blue
uniform vec4 	color_shallow : hint_color;						// Color for lower places in the water, bright blue - green
uniform float 	beers_law		 = 2.0;							// Beers law value, regulates the blending size to the deep water level
uniform float 	depth_offset	 = -0.75;						// Offset for the blending

// Projector for the water caustics:
uniform mat4	projector;										// Projector matrix, mostly the matric of the sun / directlight
// uniform sampler2DArray caustic_sampler : hint_black;			// Caustic sampler, (Texture array with 16 Textures for the animation)


// Vertex -> Fragment:
varying float 	vertex_height;									// Height of the water surface
varying vec3 	vertex_normal;									// Vertex normal -> Needed for refraction calculation
varying vec3 	vertex_binormal;								// Vertex binormal -> Needed for refraction calculation
varying vec3 	vertex_tangent;									// Vertex tangent -> Needed for refraction calculation

varying mat4 	inv_mvp; 										// Inverse ModelViewProjection matrix -> Needed for caustic projection

 
// Wave function:
vec4 wave(vec4 parameter, vec2 position, float time, inout vec3 tangent, inout vec3 binormal)
{
	float	wave_steepness	 = parameter.z;
	float	wave_length		 = parameter.w;

	float	k				 = 2.0 * 3.14159265359 / wave_length;
	float 	c 				 = sqrt(9.8 / k);
	vec2	d				 = normalize(parameter.xy);
	float 	f 				 = k * (dot(d, position) - c * time);
	float 	a				 = wave_steepness / k;
	
			tangent			+= normalize(vec3(1.0-d.x * d.x * (wave_steepness * sin(f)), d.x * (wave_steepness * cos(f)), -d.x * d.y * (wave_steepness * sin(f))));
			binormal		+= normalize(vec3(-d.x * d.y * (wave_steepness * sin(f)), d.y * (wave_steepness * cos(f)), 1.0-d.y * d.y * (wave_steepness * sin(f))));

	return vec4(d.x * (a * cos(f)), a * sin(f) * 0.25, d.y * (a * cos(f)), 0.0);
}


// Vertex shader:
void vertex()
{
	float	time			 = TIME * wave_speed;
	
	vec4	vertex			 = vec4(VERTEX, 1.0);
	vec3	vertex_position  = (WORLD_MATRIX * vertex).xyz;
	
	vec3 tang = vec3(0.0, 0.0, 0.0);
	vec3 bin = vec3(0.0, 0.0, 0.0);
	
	vertex 			+= wave(wave_a, vertex_position.xz, time, tang, bin);
	vertex 			+= wave(wave_b, vertex_position.xz, time, tang, bin);
	vertex 			+= wave(wave_c, vertex_position.xz, time, tang, bin);

	vertex_tangent 	 = tang;
	vertex_binormal  = bin;

	vertex_position  = vertex.xyz;

	vertex_height	 = (PROJECTION_MATRIX * MODELVIEW_MATRIX * vertex).z;

	TANGENT			 = vertex_tangent;
	BINORMAL		 = vertex_binormal;
	vertex_normal	 = normalize(cross(vertex_binormal, vertex_tangent));
	NORMAL			 = vertex_normal;

	UV				 = vertex.xz * sampler_scale;

	VERTEX			 = vertex.xyz;
	
	inv_mvp = inverse(PROJECTION_MATRIX * MODELVIEW_MATRIX);
}


// Fragment shader:
void fragment()
{
	// Set all values:
	ALBEDO = vec3(0.1, 0.2, 0.3);
	ALPHA = 0.95;
	METALLIC = 0.1;
	ROUGHNESS = 0.2;
	//SPECULAR = 0.2 + depth_blend_pow * 0.4;
	//NORMALMAP = normalmap;
	//NORMALMAP_DEPTH = 1.25;
}"

[sub_resource type="ShaderMaterial" id=3]
shader = SubResource( 2 )
shader_param/wave_speed = 0.5
shader_param/wave_a = Plane( 1, 1, 0.35, 3 )
shader_param/wave_b = Plane( 1, 0.6, 0.3, 1.55 )
shader_param/wave_c = Plane( 1, 1.3, 0.25, 0.9 )
shader_param/sampler_scale = Vector2( 0.25, 0.25 )
shader_param/sampler_direction = Vector2( 0.05, 0.04 )
shader_param/uv_sampler_scale = Vector2( 0.25, 0.25 )
shader_param/uv_sampler_strength = 0.04
shader_param/foam_level = 0.5
shader_param/refraction = 0.0
shader_param/color_deep = Color( 0, 0.121569, 0.184314, 1 )
shader_param/color_shallow = Color( 0.235294, 0.388235, 0.486275, 0.733333 )
shader_param/beers_law = 2.0
shader_param/depth_offset = -0.75
shader_param/projector = null

[sub_resource type="SphereShape" id=4]
radius = 40.0

[node name="Planet" type="StaticBody"]
script = ExtResource( 1 )

[node name="MeshInstance" type="MeshInstance" parent="."]

[node name="CollisionShape" type="CollisionShape" parent="."]

[node name="Water" type="MeshInstance" parent="."]
mesh = SubResource( 1 )
material/0 = SubResource( 3 )

[node name="Area" type="Area" parent="."]
space_override = 1
gravity_point = true
gravity_distance_scale = 0.02
gravity_vec = Vector3( 0, 0, 0 )
gravity = 0.0

[node name="CollisionShape" type="CollisionShape" parent="Area"]
shape = SubResource( 4 )
    [gd_scene load_steps=11 format=2]

[ext_resource path="res://Scripts/Player.gd" type="Script" id=1]

[sub_resource type="PhysicsMaterial" id=3]

[sub_resource type="CapsuleMesh" id=1]
radius = 0.2

[sub_resource type="ConvexPolygonShape" id=4]
points = PoolVector3Array( 0.0256231, 0.198131, 0.477165, -0.0323259, -0.195506, -0.518634, 0.0374641, -0.194906, -0.517066, -0.0443668, -0.185293, 0.557877, -0.193558, 0.0487689, -0.502072, 0.188777, 0.0608006, -0.517807, 0.187141, -0.0665422, 0.513254, -0.195499, -0.0323234, 0.518716, -0.0209223, 0.179497, -0.583619, -0.113909, 0.15416, 0.553594, 0.154898, 0.0963175, 0.579824, -0.146258, -0.134817, -0.509777, -0.0334188, -0.0454116, -0.691128, 0.175988, -0.0898066, -0.525782, 0.105859, -0.169451, 0.499005, -0.0334191, -0.0454121, 0.691136, 0.116602, 0.162226, -0.495911, -0.0996567, 0.17318, -0.483164, -0.134804, -0.146276, 0.509718, -0.169435, 0.105886, 0.499064, 0.0980322, 0.0622459, -0.66183, 0.162231, 0.116595, 0.495981, 0.0976438, -0.0923551, 0.647236, 0.0383689, 0.109917, 0.661606, -0.182496, -0.0783587, -0.51492, -0.116558, 0.0622243, -0.649647, 0.199544, -0.00893672, 0.492362, 0.11954, -0.1494, -0.555431, -0.128618, 0.0264656, 0.650428, 0.0256231, 0.198131, -0.477165, 0.0374637, -0.194904, 0.51706, -0.066546, 0.187152, 0.513235, 0.0945798, 0.175041, 0.51147, -0.158712, 0.117826, -0.524307, 0.0857008, -0.104195, -0.646882, -0.0921186, -0.115809, -0.63372, 0.198881, -0.0204271, -0.479134, -0.115814, -0.0921133, 0.63372, -0.0783606, -0.182485, -0.514894, -0.0546826, -0.192259, 0.475679, -0.194897, 0.0374804, 0.517142, -0.170694, -0.101378, 0.514295, 0.153258, -0.124794, 0.527139, -0.0204289, 0.19888, -0.478994, 0.13822, -0.144295, -0.468967, 0.109903, 0.0383803, 0.661608, 0.168273, -0.0446714, -0.597619, -0.19551, -0.0323254, -0.518746, -0.0332868, 0.0864491, -0.676599, 0.097294, 0.144607, -0.597565, 0.186554, 0.0715852, 0.500102, 0.162231, 0.116595, -0.495981, 0.0382434, -0.151801, 0.623578, -0.0447153, 0.16828, 0.597581, 0.179486, -0.0209148, 0.583644, 0.0263471, -0.163412, -0.610757, -0.144271, 0.138246, 0.469002, -0.163133, -0.0328778, -0.609724, 0.0828729, -0.180813, -0.510242, 0.0716033, 0.186552, -0.500048, -0.0333603, 0.0505969, 0.690007, 0.0498238, 0.167806, 0.595871, 0.0506246, -0.0333521, -0.690002, -0.115523, 0.108983, 0.620327 )

[sub_resource type="CylinderMesh" id=5]
top_radius = 0.1
bottom_radius = 0.01
height = 0.5

[sub_resource type="SpatialMaterial" id=9]
albedo_color = Color( 1, 0.196078, 0, 1 )
emission_enabled = true
emission = Color( 1, 0.0235294, 0, 1 )
emission_energy = 5.0
emission_operator = 0
emission_on_uv2 = false

[sub_resource type="CubeMesh" id=10]
material = SubResource( 9 )

[sub_resource type="Curve" id=8]
_data = [ Vector2( 0, 1 ), 0.0, 0.0, 0, 0, Vector2( 1, 0 ), 0.0, 0.0, 0, 0 ]

[sub_resource type="SpatialMaterial" id=7]
albedo_color = Color( 1, 0.196078, 0, 1 )
emission_enabled = true
emission = Color( 1, 0.588235, 0, 1 )
emission_energy = 1.0
emission_operator = 0
emission_on_uv2 = false

[sub_resource type="CubeMesh" id=6]
material = SubResource( 7 )

[node name="Player" type="RigidBody"]
physics_material_override = SubResource( 3 )
script = ExtResource( 1 )

[node name="Body" type="MeshInstance" parent="."]
mesh = SubResource( 1 )
material/0 = null

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 4 )

[node name="ThrusterUp" type="MeshInstance" parent="."]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 0 )
mesh = SubResource( 5 )
material/0 = null

[node name="Particles" type="CPUParticles" parent="ThrusterUp"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 10 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="Particles2" type="CPUParticles" parent="ThrusterUp"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 6 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="ThrusterDown" type="MeshInstance" parent="."]
transform = Transform( -1, 8.74228e-08, 0, -8.74228e-08, -1, 0, 0, 0, 1, 0, -0.1, 0 )
mesh = SubResource( 5 )
material/0 = null

[node name="Particles" type="CPUParticles" parent="ThrusterDown"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 10 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="Particles2" type="CPUParticles" parent="ThrusterDown"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 6 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="ThrusterLeft" type="MeshInstance" parent="."]
transform = Transform( -4.37114e-08, -1, 0, 1, -4.37114e-08, 0, 0, 0, 1, -0.1, -4.37114e-09, 0 )
mesh = SubResource( 5 )
material/0 = null

[node name="Particles" type="CPUParticles" parent="ThrusterLeft"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 10 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="Particles2" type="CPUParticles" parent="ThrusterLeft"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 6 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="ThrusterRight" type="MeshInstance" parent="."]
transform = Transform( 1.31134e-07, 1, 0, -1, 1.31134e-07, 0, 0, 0, 1, 0.1, 4.37114e-09, 0 )
mesh = SubResource( 5 )
material/0 = null

[node name="Particles" type="CPUParticles" parent="ThrusterRight"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 10 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="Particles2" type="CPUParticles" parent="ThrusterRight"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 6 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="ThrusterForward" type="MeshInstance" parent="."]
transform = Transform( -5.73206e-15, -4.37114e-08, -1, -1, 1.31134e-07, 0, 1.31134e-07, 1, -4.37114e-08, 0, 0, 0.509 )
mesh = SubResource( 5 )
material/0 = null

[node name="Particles" type="CPUParticles" parent="ThrusterForward"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 10 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="Particles2" type="CPUParticles" parent="ThrusterForward"]
transform = Transform( 0.0221813, -0.999754, 0, 0.999754, 0.0221813, 0, 0, 0, 1, 0, 0.263448, 0 )
cast_shadow = 0
emitting = false
amount = 200
lifetime = 8.0
local_coords = false
mesh = SubResource( 6 )
spread = 5.0
gravity = Vector3( 0, 0, 0 )
initial_velocity = 15.0
scale_amount = 0.05
scale_amount_curve = SubResource( 8 )

[node name="Camera" type="Camera" parent="."]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.592136 )
far = 1e+06
       [gd_scene load_steps=6 format=2]

[ext_resource path="res://Scripts/Star.gd" type="Script" id=1]

[sub_resource type="ConvexPolygonShape" id=1]
points = PoolVector3Array( 0.980344, 0.183469, 0.0315765, -0.977477, -0.183355, -0.0904639, -0.942976, -0.274012, -0.181475, 0.152638, -0.666639, 0.728356, -0.211037, 0.78831, 0.576929, 0.184627, -0.0915623, -0.976969, -0.180659, 0.817713, -0.543999, 0.243737, -0.909689, -0.332273, -0.121109, 0.152902, 0.979443, -0.542369, -0.724769, 0.423657, 0.604588, 0.724305, -0.330643, 0.634171, 0.391896, 0.664077, -0.879055, 0.30349, 0.365178, -0.542663, -0.422869, -0.723919, 0.852268, -0.51673, 0.0618464, -0.724288, 0.332336, -0.603236, 0.760092, -0.121365, -0.636416, 0.638071, -0.242667, 0.728959, -0.394561, 0.913095, -0.090039, 0.365549, 0.911196, 0.18319, -0.394563, -0.913101, -0.0900396, -0.604357, -0.242246, 0.757853, 0.213378, 0.424522, -0.878365, 0.274246, -0.910695, 0.304605, 0.152873, -0.667673, -0.727284, -0.332904, 0.24293, -0.909566, -0.81657, 0.545227, -0.18048, -0.66277, 0.513033, 0.544283, 0.604588, -0.724305, -0.330643, 0.243867, 0.637198, 0.72921, 0.72941, 0.637067, 0.243636, 0.154338, -0.0917767, 0.981459, 0.725418, 0.331819, -0.602295, -0.878399, -0.424493, 0.213305, 0.183583, 0.911941, -0.363567, -0.421858, -0.785457, -0.451916, 0.914484, 0.0608556, 0.39687, -0.210819, -0.423921, 0.879321, 0.726184, -0.513491, 0.454125, -0.727607, -0.667903, -0.150675, -0.120499, -0.943345, 0.305321, -0.181559, -0.365207, -0.911834, 0.91196, -0.182062, -0.363143, -0.515036, 0.242882, 0.820499, 0.544268, -0.42236, -0.723047, -0.604368, 0.756914, 0.243303, -0.121291, 0.980187, 0.1542, -0.635139, -0.151483, -0.756166, -0.943463, 0.121804, -0.30354, 0.367302, 0.152596, 0.916499, -0.51232, 0.664268, -0.542354, -0.879829, -0.121426, 0.456646, 0.518226, -0.851837, 0.0618928, 0.879357, 0.423865, -0.210791, 0.516935, 0.0908844, -0.848445, -0.241747, 0.516022, 0.820527, 0.272964, 0.694959, -0.663439, 0.0928529, -0.978183, -0.18213, -0.330847, -0.724301, 0.604471, 0.304022, 0.81782, 0.485737, -0.180675, 0.545253, -0.816525, 0.979185, -0.152614, 0.123244, -0.150676, -0.728822, -0.666713, -0.977374, 0.183336, 0.0926544 )

[sub_resource type="SphereMesh" id=2]

[sub_resource type="SpatialMaterial" id=3]
params_cull_mode = 2
emission_enabled = true
emission = Color( 1, 0.823529, 0.0196078, 1 )
emission_energy = 100.0
emission_operator = 0
emission_on_uv2 = false

[sub_resource type="SphereShape" id=4]
radius = 2.0

[node name="Star" type="StaticBody"]
transform = Transform( 30, 0, 0, 0, 30, 0, 0, 0, 30, 0, 0, 0 )
script = ExtResource( 1 )

[node name="CollisionShape" type="CollisionShape" parent="."]
shape = SubResource( 1 )

[node name="MeshInstance" type="MeshInstance" parent="."]
mesh = SubResource( 2 )
material/0 = SubResource( 3 )

[node name="OmniLight" type="OmniLight" parent="."]
omni_range = 500.0

[node name="Area" type="Area" parent="."]
space_override = 1
gravity_point = true
gravity_distance_scale = 0.02
gravity_vec = Vector3( 0, 0, 0 )
gravity = 0.0

[node name="CollisionShape" type="CollisionShape" parent="Area"]
shape = SubResource( 4 )
       [gd_scene load_steps=3 format=2]

[ext_resource path="res://Scenes/Star.tscn" type="PackedScene" id=1]
[ext_resource path="res://Scripts/System.gd" type="Script" id=2]

[node name="System" type="Spatial"]
script = ExtResource( 2 )

[node name="Star" parent="." instance=ExtResource( 1 )]
GDSC            g      ������ڶ   ������Ŷ   ����¶��   �����۶�   �����϶�   ߶��   Ŷ��   �������Ӷ���   ��������۶��   �����ض�   ��������Ҷ��   d      �        res://Scenes/System.tscn                                                           	      
                $      /      8      Y      ^      `      a      b      c      d      e      3YYYYYY;�  Y;�  �  Y;�  ?P�  QYY0�  PQV�  �%  PQ�  )�  �K  P�  R�  QV�  ;�  �  T�  PQ�  �  T�  T�	  �  P�(  P�  R�  QR�(  P�  R�  QR�(  P�  R�  QQ�  �
  P�  Q�  -YYYYYY`GDSC   8   
   A   �     ������ڶ   ���Ӷ���   ��������Ӷ��   ���Ӷ���   �����ض�   �����϶�   ����ض��   ���������޶�   ����   �����Ŷ�   �����¶�   ����Ķ��   ���޶���   ����Ӷ��   ���������������Ӷ���   ������Ŷ   �����Ҷ�   ����������Ӷ   ��������޶��   �����Ӷ�   ��������������Ŷ   ����Ŷ��   ����������������������Ŷ   ���޶���   �������������������   ��������������Ŷ   ��¶   �����������ڶ���   ������������������Ӷ   �¶�   ����������ڶ   ߶��   ���������������¶���   �����ζ�   ���������ζ�   ����������Ҷ���   ζ��   ϶��   ̶��   ����������������ڶ��   ���������ζ�   �������������Ӷ�   ����������������Ӷ��   ����������۶   ���������������Ŷ���   �����¶�   �����������Ӷ���   ��������ض��   �����������������������ض���   �������������Ӷ�   ����Ӷ��   ���¶���   �������ض���   ��������۶��   �������Ŷ���   ����׶��   
                                    ffffff�?              ��Q�@                                                    	      
                     !      %      .      8      D      K      T      \      b      m      s      |      �      �      �      �      �      �      �       �   !   �   "   �   #   �   $   �   %     &     '     (     )     *   "  +   (  ,   0  -   1  .   8  /   B  0   I  1   K  2   L  3   R  4   V  5   p  6   v  7   w  8   x  9     :   �  ;   �  <   �  =   �  >   �  ?   �  @   �  A   3YYYYYY;�  Y;�  �  Y;�  �  Y;�  YYY0�  PQV�  �%  PQ�  ;�  �  T�  PQ�  �  T�	  P�  �  Q�  �  T�
  P�  �  Q�  �  W�  T�  �  �  ;�  �  T�  PQ�  �  T�)  �&  PQ�  �  T�  �  �  �  T�  �(  P�  R�  Q�  �  T�  �  �  ;�  �  T�  PQ�  ;�  �  T�  PQ�  �  T�  �  �  �  T�  �  �  �  T�  P�  T�  R�  T�  PQQ�  ;�  �  T�  PQ�  �  T�  P�  R�  Q�  ;�  �  T�  PQ�  �  )�  �K  P�  T�   PQQV�  ;�!  �  T�"  P�  Q�  ;�
  P�  T�#  P�!  T�$  R�!  T�%  R�!  T�&  QQ�  �!  �  T�'  P�  Q�  �  �!  �  T�'  P�  Q�  �
  �  �  �  T�(  P�  R�!  Q�  �  T�)  P�  Q�  �  T�*  P�  Q�  �  T�+  P�  R�  Q�  �  T�,  PQ�  �  �  T�-  PQ�  �  W�.  T�  �  �  ;�/  W�.  T�0  PQ�  W�1  T�2  �/  �  -YY0�3  PQV�  �%  PQ�  �4  �  P�(  P�  R�	  QR�(  P�  R�	  QR�(  P�  R�	  QQ�  �  �5  T�  YYY0�6  P�7  QV�  �  �  �  �  �  �  -Y`       GDSC         5   �     ��������϶��   ����Ҷ��   ��������Ҷ��   ���������Ҷ�   �����϶�   ��������¶��   ����׶��   ��������Ŷ��   ���������ƶ�   ��������Ŷ��   �����������ض���   �����������¶���   ������������¶��   ��������������Ҷ   ��������ń��   ��������ń��   �������Ѷ���   ����¶��   ����������������Ҷ��   ��������������������Ӷ��   ��������۶��   ����Ŷ��   ϶��   �������������������Ӷ���   ζ��   ̶��   �������Ŷ���  �������?        {�G�z�?             ui_down       ui_up               ui_right            ui_left          	   ui_accept                                                       	      
                            !      "      #      *      H      f      t      �      �      �      �      �      �      �      �      �      �              !     "   &  #   2  $   ;  %   G  &   R  '   [  (   f  )   r  *   {  +   �  ,   �  -   �  .   �  /   �  0   �  1   �  2   �  3   �  4   �  5   3YYYYYY;�  Y;�  �  Y;�  �  YYY0�  PQV�  -Y�  YY0�  P�  QV�  ;�  LW�  �	  RW�
  �	  RW�  �	  RW�  �	  RW�  �	  M�  ;�  LW�  �  RW�
  �  RW�  �  RW�  �  RW�  �  M�  �  L�  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�	  Q�  �  L�
  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�  Q�  �  L�  MT�  �  T�  P�	  Q�  �  L�
  MT�  �  T�  P�  Q�  &�  T�  P�  QV�  �  P�  T�  T�  �  Q�  �  P�  T�  T�  �  Q�  &�  T�  P�  QV�  �  P�  T�  T�  �  Q�  �  P�  T�  T�  �  Q�  &�  T�  P�	  QV�  �  P�  T�  T�  �  Q�  �  P�  T�  T�  �  Q�  &�  T�  P�  QV�  �  P�  T�  T�  �  Q�  �  P�  T�  T�  �  Q�  &�  T�  P�  QV�  �  �  �  �  �  P�  T�  T�  �  Q�  YYY0�  P�  QV�  �  P�  Q�  &�  �  V�  �  �  YY`         GDSC            X      �����׶�   �����ض�   ���ض���   �����϶�   ���������¶�   ��������۶��   �������Ӷ���   ���������������۶���   �������Ŷ���   ����׶��   �������ض���      Player                                                      	      
                           -      /      0      1      8      D      U      V      3YYYYYYY;�  Y;�  YYY0�  PQV�  �  �  PQ�  �  �  T�  �  T�  PQT�  T�  �  -YYY0�  P�	  QV�  �
  �  T�  PQT�
  �  �  T�  �  T�  PQT�  T�  �  YY`  GDSC            /      ���������϶�   �����϶�   ���Ӷ���   ����Ӷ��   
                                                    	   	   
   
               &      (      )      *      +      ,      -      3YYYYYYYYY0�  PQV�  ;�  �&  PQ�  �  �  P�  R�  R�  Q�  -YYYYYY`    GDSC            w      ������ڶ   �����¶�   �����϶�   ߶��   ƶ��   �������Ӷ���   �������Ӷ���   ����Ӷ��   ��������۶��   �����ض�   ��������Ҷ��   ���¶���      res://Scenes/Planet.tscn                      
     ��Q�@                                                    	      
               *      3      >      Y      c      h      n      p      q      r      s      t      u      3YYYYYY;�  ?PQYYY0�  PQV�  �%  PQ�  )�  �K  P�  R�&  PQ�  QV�  ;�  �  T�  PQ�  ;�  �&  PQ�  �  �  ;�  �  P�(  P�  R�  QR�(  P�  R�  QR�(  P�  R�  QQ�  �  T�  T�	  �  �  �  �
  P�  Q�  �  T�  PQ�  -YYYYYY` [gd_resource type="Environment" load_steps=2 format=2]

[sub_resource type="ProceduralSky" id=1]

[resource]
background_mode = 2
background_sky = SubResource( 1 )
             GDST@   @            �  WEBPRIFF�  WEBPVP8L�  /?����m��������_"�0@��^�"�v��s�}� �W��<f��Yn#I������wO���M`ҋ���N��m:�
��{-�4b7DԧQ��A �B�P��*B��v��
Q�-����^R�D���!(����T�B�*�*���%E["��M�\͆B�@�U$R�l)���{�B���@%P����g*Ųs�TP��a��dD
�6�9�UR�s����1ʲ�X�!�Ha�ߛ�$��N����i�a΁}c Rm��1��Q�c���fdB�5������J˚>>���s1��}����>����Y��?�TEDױ���s���\�T���4D����]ׯ�(aD��Ѓ!�a'\�G(��$+c$�|'�>����/B��c�v��_oH���9(l�fH������8��vV�m�^�|�m۶m�����q���k2�='���:_>��������á����-wӷU�x�˹�fa���������ӭ�M���SƷ7������|��v��v���m�d���ŝ,��L��Y��ݛ�X�\֣� ���{�#3���
�6������t`�
��t�4O��ǎ%����u[B�����O̲H��o߾��$���f���� �H��\��� �kߡ}�~$�f���N\�[�=�'��Nr:a���si����(9Lΰ���=����q-��W��LL%ɩ	��V����R)�=jM����d`�ԙHT�c���'ʦI��DD�R��C׶�&����|t Sw�|WV&�^��bt5WW,v�Ş�qf���+���Jf�t�s�-BG�t�"&�Ɗ����׵�Ջ�KL�2)gD� ���� NEƋ�R;k?.{L�$�y���{'��`��ٟ��i��{z�5��i������c���Z^�
h�+U�mC��b��J��uE�c�����h��}{�����i�'�9r�����ߨ򅿿��hR�Mt�Rb���C�DI��iZ�6i"�DN�3���J�zڷ#oL����Q �W��D@!'��;�� D*�K�J�%"�0�����pZԉO�A��b%�l�#��$A�W�A�*^i�$�%a��rvU5A�ɺ�'a<��&�DQ��r6ƈZC_B)�N�N(�����(z��y�&H�ض^��1Z4*,RQjԫ׶c����yq��4���?�R�����0�6f2Il9j��ZK�4���է�0؍è�ӈ�Uq�3�=[vQ�d$���±eϘA�����R�^��=%:�G�v��)�ǖ/��RcO���z .�ߺ��S&Q����o,X�`�����|��s�<3Z��lns'���vw���Y��>V����G�nuk:��5�U.�v��|����W���Z���4�@U3U�������|�r�?;�
         [remap]

importer="texture"
type="StreamTexture"
path="res://.import/icon.png-487276ed1e3a0c39cad0279d744ee560.stex"
metadata={
"vram_texture": false
}

[deps]

source_file="res://icon.png"
dest_files=[ "res://.import/icon.png-487276ed1e3a0c39cad0279d744ee560.stex" ]

[params]

compress/mode=0
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=0
flags/filter=true
flags/mipmaps=false
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit=0
detect_3d=true
svg/scale=1.0
              [remap]

path="res://Scripts/Main.gdc"
         [remap]

path="res://Scripts/Planet.gdc"
       [remap]

path="res://Scripts/Player.gdc"
       [remap]

path="res://Scripts/PlayerCamera.gdc"
 [remap]

path="res://Scripts/Star.gdc"
         [remap]

path="res://Scripts/System.gdc"
       �PNG

   IHDR   @   @   �iq�   sRGB ���  �IDATx��ytTU��?�ի%���@ȞY1JZ �iA�i�[P��e��c;�.`Ow+4�>�(}z�EF�Dm�:�h��IHHB�BR!{%�Zߛ?��	U�T�
���:��]~�������-�	Ì�{q*�h$e-
�)��'�d�b(��.�B�6��J�ĩ=;���Cv�j��E~Z��+��CQ�AA�����;�.�	�^P	���ARkUjQ�b�,#;�8�6��P~,� �0�h%*QzE� �"��T��
�=1p:lX�Pd�Y���(:g����kZx ��A���띊3G�Di� !�6����A҆ @�$JkD�$��/�nYE��< Q���<]V�5O!���>2<��f��8�I��8��f:a�|+�/�l9�DEp�-�t]9)C�o��M~�k��tw�r������w��|r�Ξ�	�S�)^� ��c�eg$�vE17ϟ�(�|���Ѧ*����
����^���uD�̴D����h�����R��O�bv�Y����j^�SN֝
������PP���������Y>����&�P��.3+�$��ݷ�����{n����_5c�99�fbסF&�k�mv���bN�T���F���A�9�
(.�'*"��[��c�{ԛmNު8���3�~V� az
�沵�f�sD��&+[���ke3o>r��������T�]����* ���f�~nX�Ȉ���w+�G���F�,U�� D�Դ0赍�!�B�q�c�(
ܱ��f�yT�:��1�� +����C|��-�T��D�M��\|�K�j��<yJ, ����n��1.FZ�d$I0݀8]��Jn_� ���j~����ցV���������1@M�)`F�BM����^x�>
����`��I�˿��wΛ	����W[�����v��E�����u��~��{R�(����3���������y����C��!��nHe�T�Z�����K�P`ǁF´�nH啝���=>id,�>�GW-糓F������m<P8�{o[D����w�Q��=N}�!+�����-�<{[���������w�u�L�����4�����Uc�s��F�륟��c�g�u�s��N��lu���}ן($D��ת8m�Q�V	l�;��(��ڌ���k�
s\��JDIͦOzp��مh����T���IDI���W�Iǧ�X���g��O��a�\:���>����g���%|����i)	�v��]u.�^�:Gk��i)	>��T@k{'	=�������@a�$zZ�;}�󩀒��T�6�Xq&1aWO�,&L�cřT�4P���g[�
p�2��~;� ��Ҭ�29�xri� ��?��)��_��@s[��^�ܴhnɝ4&'
��NanZ4��^Js[ǘ��2���x?Oܷ�$��3�$r����Q��1@�����~��Y�Qܑ�Hjl(}�v�4vSr�iT�1���f������(���A�ᥕ�$� X,�3'�0s����×ƺk~2~'�[�ё�&F�8{2O�y�n�-`^/FPB�?.�N�AO]]�� �n]β[�SR�kN%;>�k��5������]8������=p����Ցh������`}�
�J�8-��ʺ����� �fl˫[8�?E9q�2&������p��<�r�8x� [^݂��2�X��z�V+7N����V@j�A����hl��/+/'5�3�?;9
�(�Ef'Gyҍ���̣�h4RSS� ����������j�Z��jI��x��dE-y�a�X�/�����:��� +k�� �"˖/���+`��],[��UVV4u��P �˻�AA`��)*ZB\\��9lܸ�]{N��礑]6�Hnnqqq-a��Qxy�7�`=8A�Sm&�Q�����u�0hsPz����yJt�[�>�/ޫ�il�����.��ǳ���9��
_
��<s���wT�S������;F����-{k�����T�Z^���z�!t�۰؝^�^*���؝c
���;��7]h^
��PA��+@��gA*+�K��ˌ�)S�1��(Ե��ǯ�h����õ�M�`��p�cC�T")�z�j�w��V��@��D��N�^M\����m�zY��C�Ҙ�I����N�Ϭ��{�9�)����o���C���h�����ʆ.��׏(�ҫ���@�Tf%yZt���wg�4s�]f�q뗣�ǆi�l�⵲3t��I���O��v;Z�g��l��l��kAJѩU^wj�(��������{���)�9�T���KrE�V!�D���aw���x[�I��tZ�0Y �%E�͹���n�G�P�"5FӨ��M�K�!>R���$�.x����h=gϝ�K&@-F��=}�=�����5���s �CFwa���8��u?_����D#���x:R!5&��_�]���*�O��;�)Ȉ�@�g�����ou�Q�v���J�G�6�P�������7��-���	պ^#�C�S��[]3��1���IY��.Ȉ!6\K�:��?9�Ev��S]�l;��?/� ��5�p�X��f�1�;5�S�ye��Ƅ���,Da�>�� O.�AJL(���pL�C5ij޿hBƾ���ڎ�)s��9$D�p���I��e�,ə�+;?�t��v�p�-��&����	V���x���yuo-G&8->�xt�t������Rv��Y�4ZnT�4P]�HA�4�a�T�ǅ1`u\�,���hZ����S������o翿���{�릨ZRq��Y��fat�[����[z9��4�U�V��Anb$Kg������]������8�M0(WeU�H�\n_��¹�C�F�F�}����8d�N��.��]���u�,%Z�F-���E�'����q�L�\������=H�W'�L{�BP0Z���Y�̞���DE��I�N7���c��S���7�Xm�/`�	�+`����X_��KI��^��F\�aD�����~�+M����ㅤ��	SY��/�.�`���:�9Q�c �38K�j�0Y�D�8����W;ܲ�pTt��6P,� Nǵ��Æ�:(���&�N�/ X��i%�?�_P	�n�F�.^�G�E���鬫>?���"@v�2���A~�aԹ_[P, n��N������_rƢ��    IEND�B`�       ECFG      application/config/name         Starfire   application/run/main_scene          res://Scenes/Main.tscn     application/config/icon         res://icon.png     display/window/size/width            display/window/size/height      �      display/window/stretch/mode         viewport   display/window/stretch/aspect         keep   global/gravity             input/ui_left�              deadzone      ?      events              InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode        physical_scancode             unicode           echo          script            InputEventJoypadButton        resource_local_to_scene           resource_name             device            button_index         pressure          pressed           script            InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode   A      physical_scancode             unicode           echo          script         input/ui_right�              deadzone      ?      events              InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode        physical_scancode             unicode           echo          script            InputEventJoypadButton        resource_local_to_scene           resource_name             device            button_index         pressure          pressed           script            InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode   D      physical_scancode             unicode           echo          script         input/ui_up�              deadzone      ?      events              InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode        physical_scancode             unicode           echo          script            InputEventJoypadButton        resource_local_to_scene           resource_name             device            button_index         pressure          pressed           script            InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode   W      physical_scancode             unicode           echo          script         input/ui_down�              deadzone      ?      events              InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode        physical_scancode             unicode           echo          script            InputEventJoypadButton        resource_local_to_scene           resource_name             device            button_index         pressure          pressed           script            InputEventKey         resource_local_to_scene           resource_name             device            alt           shift             control           meta          command           pressed           scancode   S      physical_scancode             unicode           echo          script      )   physics/common/enable_pause_aware_picking            physics/3d/default_gravity          !   physics/3d/default_gravity_vector                  $   rendering/quality/driver/driver_name         GLES2   %   rendering/vram_compression/import_etc         &   rendering/vram_compression/import_etc2          )   rendering/environment/default_environment          res://default_env.tres      