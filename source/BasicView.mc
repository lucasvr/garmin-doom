using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Graphics as Gfx;
using Toybox.UserProfile as UserProfile;

enum {
  SCREEN_SHAPE_CIRC     = 0x000001,
  SCREEN_SHAPE_SEMICIRC = 0x000002,
  SCREEN_SHAPE_RECT     = 0x000003
}

class ScreenPosition {
    var x = null;
    var y = null;
    var h = null;
    var w = null;

    function initialize() {
    }

    function setXY(_x,_y) {
        x = _x;
        y = _y;
    }

    function setHW(_h,_w) {
        h = _h;
        w = _w;
    }
}

class BasicView extends Ui.DataField {
    // Bitmaps and fonts
    var bitmap_faces = null;
    var doom_font14 = null;
    var doom_font20 = null;

    // Location of various features on screen
    var hr_textbox = new ScreenPosition();
    var hr_data = new ScreenPosition();
    var speed_textbox = new ScreenPosition();
    var speed_data = new ScreenPosition();
    var statusbar = new ScreenPosition();

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
        // Draw our objects
        drawStaticGFX(dc);
        drawDoomFace(dc);
        drawStatistics(dc);
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
        var elevation = current_altitude;
        if (elevation != null) {
            // Update altitude profile
            var curr = altitude_index;
            var prev = altitude_last_index;
            var prev_altitude = altitude[prev];
            altitude[curr] = elevation;

            // Damn simple climb detection
            var is_climbing = false;
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

            if (is_climbing) {
                // Tough face
                return 0;
            }
        }

        if (current_speed != null && current_speed > 40) {
            // Tough face
            return 0;
        }

        // Fallback: regular face
        return 1;
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
            // First group
            case 0: sprite_x = 1; break;
            case 1: sprite_x = prev_sprite_x == 0 ? 2 : 0; break;
            case 2: sprite_x = 1; break;

            // Second group
            case 3: sprite_x = 4; break;
            case 4: sprite_x = prev_sprite_x == 3 ? 5 : 3; break;
            case 5: sprite_x = 4; break;
        }
        prev_sprite_x = prev_x;

        sprite_y = getDamageLevel();

        // Define which area of the screen we will render on
        var offset_x = canvas_width/2 - sprite_width/2;
        var offset_y = canvas_height - sprite_height;
        dc.setClip(
            offset_x,
            offset_y,
            sprite_width,
            sprite_height);

        // Draw the current face
        var padding_x = 4;
        var padding_y = 4;
        var x = (-padding_x * (sprite_x+1)) - (sprite_x*sprite_width);
        var y = (-padding_y * (sprite_y+1)) - (sprite_y*sprite_height);
        dc.drawBitmap(
            x + offset_x,
            y + offset_y,
            bitmap_faces);
    }

    function initPositions() {
        // Heart rate definitions
        hr_data.setXY(
            sprite_width/4,
            canvas_height - sprite_height);
        hr_data.setHW(40, sprite_width);

        hr_textbox.setXY(
            hr_data.x,
            hr_data.y + hr_data.h);
        hr_textbox.setHW(20, hr_data.w);

        // Speed definitions
        speed_data.setXY(
            canvas_width/2 + sprite_width/2 + 20,
            canvas_height - sprite_height);
        speed_data.setHW(40, sprite_width);

        speed_textbox.setXY(
            speed_data.x-10,
            speed_data.y + speed_data.h);
        speed_textbox.setHW(20, speed_data.w+20);

        // Status bar
        statusbar.setXY(0, hr_data.y);
        statusbar.setHW(canvas_height - statusbar.y, canvas_width);
    }

    function drawStaticGFX(dc) {
        if (hr_data.x == null) {
            initPositions();
        }

        // Background color
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, canvas_width, canvas_height);

        // GFX: Status bar
        if (false) {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_DK_GRAY);
            dc.fillRectangle(statusbar.x, statusbar.y, statusbar.w, statusbar.h);
            dc.setColor(Gfx.COLOR_LT_GRAY, 0x3b3b3b);
            dc.drawLine(statusbar.x, statusbar.y, canvas_width, statusbar.y);
            dc.drawLine(statusbar.x, canvas_height, canvas_width, canvas_height);
        }

        // GFX: Heart Rate
        dc.setClip(hr_textbox.x, hr_textbox.y, hr_textbox.w, hr_textbox.h);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(
            hr_textbox.x*2,
            hr_textbox.y,
            doom_font14,
            "HR",
            Gfx.TEXT_JUSTIFY_LEFT
        );

        // GFX: Speed
        dc.setClip(speed_textbox.x, speed_textbox.y, speed_textbox.w, speed_textbox.h);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(
            speed_textbox.x,
            speed_textbox.y,
            doom_font14,
            "Speed",
            Gfx.TEXT_JUSTIFY_LEFT
        );
    }

    function drawStatistics(dc) {
        // Heart Rate
        dc.setClip(hr_data.x, hr_data.y, hr_data.w, hr_data.h);
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_BLACK);
        dc.drawText(
            hr_data.x*5,
            hr_data.y,
            doom_font20,
            current_hr == null ? "---" : current_hr.format("%03d"),
            Gfx.TEXT_JUSTIFY_RIGHT
        );

        // Speed
        dc.setClip(speed_data.x, speed_data.y, speed_data.w, speed_data.h);
        dc.drawText(
            speed_data.x,
            speed_data.y,
            doom_font20,
            current_speed == null ? "--" : current_speed.format("%02d"),
            Gfx.TEXT_JUSTIFY_LEFT
        );
    }
}
