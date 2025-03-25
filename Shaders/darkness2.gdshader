shader_type canvas_item;

uniform vec4 room_area : source_color; // Define the area of the rooms
uniform float dark_strength : hint_range(0.0, 1.0) = 1.0; // Darkness strength (opacity of the darkened areas)

void fragment() {
    vec2 screen_pos = FRAGCOORD.xy / SCREEN_PIXEL_SIZE;

    // Check if the current fragment (pixel) is within the room area (based on your gridmap's position/size)
    if (screen_pos.x > room_area.x && screen_pos.x < room_area.z &&
        screen_pos.y > room_area.y && screen_pos.y < room_area.w) {
        // If in the room area, leave it unaffected (clear)
        COLOR = texture(TEXTURE, FRAGCOORD.xy);
    } else {
        // If outside the room area, apply darkness
        COLOR = vec4(0.0, 0.0, 0.0, dark_strength); // Adjust RGB and alpha for darkness
    }
}
