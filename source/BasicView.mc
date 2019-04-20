using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Graphics as Gfx;
using Toybox.UserProfile as UserProfile;

enum {
  SCREEN_SHAPE_CIRC     = 0x000001,
  SCREEN_SHAPE_SEMICIRC = 0x000002,
  SCREEN_SHAPE_RECT     = 0x000003
}

class BasicView extends Ui.DataField {
    // Bitmaps and fonts
    var bitmap_faces = null;
    var doom_font14 = null;
    var doom_font20 = null;

    // Timer related variables. We attempt to draw one frame every 500ms
    var timer_obj = null;
    var timer_timeout = 500;
    var timer_steps = timer_timeout;

    // Activity
    var current_hr = null;
    var current_speed = null;
    var current_altitude = null;

    // User profile
    var this_sport;
    var hr_zones;

    // Sprite grid we care about is 6x5. We just ignore the elements
    // featured in the other cells. There are two rendering groups, too,
    // that we pick depending on the activity's effort. If the athlete is
    // pushing beyond her limits, we render from X indexes 0-2 (tough faces)
    // On a regular workout we render from X indexes 3-5. An activity begins
    // with a regular workout effort face (X index 4)
    var sprite_height = 62;
    var sprite_width = 48;
    var sprite_x = 4;
    var sprite_y = 0;
    var prev_sprite_x = sprite_x - 1;

    // Canvas properties
    var canvas_height = 0;
    var canvas_width = 0;

    // Create an array to store climbing data. To have 5 seconds of data at
    // a sampling rate of 500ms we need 10 entries on the array.
    var climb_count = 0;
    var altitude_len = 10;
    var altitude_index = 0;
    var altitude_last_index = 0;
    var altitude = [
        null, null, null, null, null,
        null, null, null, null, null
    ];

    function initialize() {
        Ui.DataField.initialize();
    }

    //! Load your resources here
    function onLayout(dc) {
        // Bitmap and fonts
        bitmap_faces = Ui.loadResource(Rez.Drawables.DoomFaces);
        doom_font14 = Ui.loadResource(Rez.Fonts.DoomFont14);
        doom_font20 = Ui.loadResource(Rez.Fonts.DoomFont20);

        // Canvas width, height
        canvas_width = dc.getWidth();
        canvas_height = dc.getHeight();

        this_sport = UserProfile.getCurrentSport();
        if (this_sport == null) {
            this_sport = HR_ZONE_SPORT_GENERIC;
        }
        hr_zones = UserProfile.getHeartRateZones(this_sport);

        setLayout(Rez.Layouts.MainLayout(dc));
        return true;
    }

    function compute(info) {
        if (info has :currentHeartRate) {
            // Given in beats per minute
            current_hr = info.currentHeartRate;
        }
        if (info has :currentSpeed) {
            // Convert from m/s to km/h
            current_speed = info.currentSpeed * 3.6;
        }
        if (info has :altitude) {
            // Altitude is given in meters
            current_altitude = info.altitude;
        }
     }

    //! Update the view
    function onUpdate(dc) {
        // Reset the clip to cover the entire screen
        dc.setClip(
            0,
            0,
            canvas_width,
            canvas_height);

        // Redraw the layout
        View.onUpdate(dc);

        // Heart Rate
        var hr_data = current_hr == null ? "---" : current_hr.format("%03d");
        View.findDrawableById("HRData").setText(hr_data);

        // Speed
        var speed_data = current_speed == null ? "---" : current_speed.format("%02d");
        View.findDrawableById("SpeedData").setText(speed_data);

        // Doom face
        drawDoomFace(dc);
    }

    function getDamageLevel() {
        // Determine damage level according to the current activity's efforts.
        // We have 5 possible levels, ranging from 0 (easy) to 4 (hard), that
        // are currently based on the heart rate zones configured by the user.
        if (current_hr != null && hr_zones != null) {
            if (current_hr < hr_zones[1]) {
                return 0;
            } else if (current_hr < hr_zones[2]) {
                return 1;
            } else if (current_hr < hr_zones[3]) {
                return 2;
            } else if (current_hr < hr_zones[4]) {
                return 3;
            } else {
                return 4;
            }
        }
        // Fallback: easy level
        return 0;
    }

    function getStaminaLevel() {
        // Get stamina level. There are two possible modes: 0 (excited)
        // and 1 (normal). This information is currently based on the
        // speed and on climbing data.
        var is_climbing = false;
        var elevation = current_altitude;
        if (elevation != null) {
            // Update altitude profile
            var curr = altitude_index;
            var prev = altitude_last_index;
            var prev_altitude = altitude[prev];
            altitude[curr] = elevation;

            // Damn simple climb detection
            if (prev_altitude != null) {
                if (altitude[prev] > altitude[curr]) {
                    climb_count = 0;
                } else {
                    climb_count += 1;
                    if (climb_count >= altitude_len) {
                        is_climbing = true;
                        climb_count -= 1;
                    }
                }
            }

            // Update pointers
            altitude_last_index = curr;
            altitude_index += 1;
            if (altitude_index >= altitude_len) {
                altitude_index = 0;
            }
        }

        if (is_climbing || (current_speed != null && current_speed > 40)) {
            // Tough face
            return 0;
        } else {
            // Regular face
            return 1;
        }
    }

    function drawDoomFace(dc) {
        // Potentially change stamina level prior to the
        // determination of the next sprite
        var stamina = getStaminaLevel();
        if (stamina == 0 && sprite_x >= 3) {
            prev_sprite_x -= 3;
            sprite_x -= 3;
        } else if (stamina == 1 && sprite_x < 3) {
            prev_sprite_x += 3;
            sprite_x += 3;
        }

        // Determine next sprite
        var prev_x = sprite_x;
        switch (sprite_x) {
            // First group (tough face)
            case 0: sprite_x = 1; break;
            case 1: sprite_x = prev_sprite_x == 0 ? 2 : 0; break;
            case 2: sprite_x = 1; break;

            // Second group (normal face)
            case 3: sprite_x = 4; break;
            case 4: sprite_x = prev_sprite_x == 3 ? 5 : 3; break;
            case 5: sprite_x = 4; break;
        }
        prev_sprite_x = prev_x;
        sprite_y = getDamageLevel();

        // Draw the sprite
        var offset_x = canvas_width/2 - sprite_width/2;
        var offset_y = canvas_height - sprite_height;
        var padding_x = 4;
        var padding_y = 4;
        var x = (-padding_x * (sprite_x+1)) - (sprite_x*sprite_width);
        var y = (-padding_y * (sprite_y+1)) - (sprite_y*sprite_height);
        dc.setClip(
            offset_x,
            offset_y,
            sprite_width,
            sprite_height);
        dc.drawBitmap(
            x + offset_x,
            y + offset_y,
            bitmap_faces);
    }
}
