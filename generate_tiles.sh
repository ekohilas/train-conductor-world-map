#!/bin/sh

overwrite="true"

main()
{
    csv_file="$1"
    output_directory="$2"

    if [ "$#" -eq 1 ]
    then
        output_directory="tiles"
    elif [ "$#" -ne 2 ]
    then
        echo "Usage: $0 <tiles.csv> [output_directory]"
        exit 1
    fi

    num_cols_expected="24"
    num_cols_actual="$(cat "$csv_file" | head -1 | sed 's/,/,,/' | tr -cd ',' | wc -c)"
    if [ "$num_cols_actual" -ne 27 ]
    then
        echo "$csv_file has the wrong number of columns:"
        echo "Expected $num_cols_expected, found $num_cols_actual."
        exit 1
    fi

    magick_version="$(convert -version | head -1 | cut -d ' ' -f 3 | cut -d '.' -f 1)"
    if [ "$magick_version" -lt 7 ]
    then
        echo "Warning: Detected a version of ImageMagick older than 7. This script was tested with ImageMagick version 7.1.0-19 and may not run correctly."
    fi

    delegates="$(convert -version | grep "Delegates.*png")"
    if [ "$?" -ne 0 ]
    then
        echo "Warning: Detected missing png delegate. This script may not work correctly. The following delegates were found:"
        echo "$delegates"
    fi

    size="64"
    color_rail="#fff99b"
    color_plank="#b8796a"

    if [ -f "$output_directory" ]
    then
        echo "$output_directory is not a directory."
    elif [ ! -d "$output_directory" ]
    then
        mkdir -p "$output_directory"
    fi

    generate_all \
        "$csv_file" \
        "$size" \
        "$color_planks" \
        "$color_rail" \
        "$output_directory"
}

log()
{
    if [ true ]
    then
        echo "$@"
    fi
}

generate_all()
{
    if [ "$#" -ne 5 ]
    then
        echo "Usage: generate_all <tiles.csv> <size_px> <planks_hex_color> <rails_hex_color> <output_directory>"
        exit 1
    fi

    csv_file="$1"
    size="$2"
    color_planks="$3"
    color_rail="$4"
    output_directory="$5"

    base_straight_planks_filepath="$(mktemp).png"
    base_straight_rails_filepath="$(mktemp).png"
    base_curve_planks_filepath="$(mktemp).png"
    base_curve_rails_filepath="$(mktemp).png"

    generate_straight_track \
        "$size" \
        "$color_planks" \
        "$color_rail" \
        "$base_straight_planks_filepath" \
        "$base_straight_rails_filepath"

    generate_curve_track \
        "$base_straight_planks_filepath" \
        "$base_straight_rails_filepath" \
        "$base_curve_planks_filepath" \
        "$base_curve_rails_filepath"

    base_color_connection="#ffffff"

    base_straight_connection_filepath="$(mktemp).png"
    base_curve_connection_filepath="$(mktemp).png"

    generate_straight_connection \
        "$size" \
        "$size" \
        "$base_color_connection" \
        "$base_straight_connection_filepath"

    generate_curve_connection \
        "$base_straight_connection_filepath" \
        "$base_curve_connection_filepath"

    generate_from_csv \
        "$csv_file" \
        "$base_straight_planks_filepath" \
        "$base_straight_rails_filepath" \
        "$base_curve_planks_filepath" \
        "$base_curve_rails_filepath" \
        "$base_straight_connection_filepath" \
        "$base_curve_connection_filepath" \
        "$output_directory"
}

generate_straight_track()
{
    if [ "$#" -ne 5 ]
    then
        echo "Usage: generate_straight_track <size> <planks_hex_color> <rails_hex_color> <base_straight_planks_output_filepath> <base_straight_rails_output_filepath>"
        exit 1
    fi

    size="$1"
    color_planks="$2"
    color_rail="$3"
    base_straight_planks="$4"
    base_straight_rails="$5"

    height="$size"
    width="$size"

    generate_straight_planks \
        "$height" \
        "$width" \
        "$color_planks" \
        "$base_straight_planks"

    generate_straight_rails \
        "$height" \
        "$width" \
        "$color_rails" \
        "$base_straight_rails"
}

generate_straight_planks()
{
    if [ "$#" -ne 4 ]
    then
        echo "Usage: generate_straight_planks <height> <width> <planks_hex_color> <base_straight_planks_output_filepath>"
        exit 1
    fi

    height="$1"
    width="$2"
    color_planks="$3"
    base_straight_planks="$4"

    log "Generating base straight planks..."

    height_original="64"
    width_original="64"

    num_planks="8"

    plank_partition_width_original="8"
    plank_partition_width="( $width / $num_planks )"

    plank_width_original="4"
    plank_width_to_partition_ratio="( $plank_width_original / $plank_partition_width_original )"
    plank_width="$(echo "scale=6; $plank_partition_width * $plank_width_to_partition_ratio" | bc)"

    plank_center_offset_x_from_partition="( $plank_partition_width / 2 )"
    plank_center_x="$(echo "scale=6; $plank_center_offset_x_from_partition - 0.5" | bc)"

    plank_height_original="16"
    plank_height_ratio="( $plank_height_original / $height_original )"
    plank_height="( $height * $plank_height_ratio )"

    plank_height_y_original="24"
    plank_height_y="$(echo "scale=6; $width / 2 - $plank_height / 2" | bc)"

    plank_height_svg="$(echo "scale=6; $plank_height - 1" | bc )"

    paths=""
    for plank in $(seq 0 "$(echo "$num_planks/1 - 1" | bc)")
    do
        plank_x="$(echo "scale=6; $plank_center_x + $plank * $plank_partition_width" | bc)"
        path="path 'M $plank_x,$plank_height_y l 0,$plank_height_svg'"
        paths="$paths $path"
    done

    convert \
        -size "${width}x${height}" \
        canvas:none \
        -stroke "$color_plank" \
        -strokewidth "$plank_width" \
        +antialias \
        -draw "$paths" \
        -strip \
        "$base_straight_planks"

    log "Saved      base straight planks to $base_straight_planks"
}

generate_straight_rails()
{
    if [ "$#" -ne 4 ]
    then
        echo "Usage: generate_straight_rails <height> <width> <rails_hex_color> <base_straight_rails_output_filepath>"
        exit 1
    fi

    height="$1"
    width="$2"
    color_rails="$3"
    base_straight_rails="$4"

    log "Generating base straight rails..."

    height_original="64"
    width_original="64"

    center_rail_original="28"
    center_rail_offset_from_center_ratio="( ( $height_original / 2 - $center_rail_original ) / $height_original )"
    center_rail_offset_from_center="( $center_rail_offset_from_center_ratio * $height )"

    rail_center_y="$(echo "scale=6; ( $height / 2 - $center_rail_offset_from_center )" | bc)"

    rail_width_original="3"
    rail_width_to_size_ratio="( $rail_width_original / $width_original )"
    rail_width="$(echo "scale=6; ( $rail_width_to_size_ratio * $height )" | bc)"

    convert \
        -size "${width}x${height}" \
        canvas:none \
        -stroke "$color_rail" \
        -strokewidth "$rail_width" \
        +antialias \
        -draw "path 'M 0,$rail_center_y l $width,0'" \
        \( +clone -flip \) \
        -composite \
        -strip \
        "$base_straight_rails"

    log "Saved      base straight rails to $base_straight_rails"
}

generate_curve_track()
{

    if [ "$#" -ne 4 ]
    then
        echo "Usage: generate_curve_track <base_straight_planks_filepath.png> <base_straight_rails_filepath.png> <base_curve_planks_output_filepath> <base_curve_rails_output_filepath>"
        exit 1
    fi

    base_straight_planks="$1"
    base_straight_rails="$2"
    base_curve_planks="$3"
    base_curve_rails="$4"

    map_p_angle="$(mktemp).png"
    map_p_radius="$(mktemp).png"

    image_size="$(identify -ping -format '%w %h' "$base_straight_rails")"
    width=${image_size% *}
    height=${image_size#* }

    convert \
        -size "${width}x${height}" \
        canvas: \
        -channel G \
        -fx 'atan((j+0.5)/(i+0.5))*2/pi' \
        -separate \
        -strip \
        "$map_p_angle"

    convert \
        -size "${width}x${height}" \
        canvas: \
        -channel G \
        -fx '1-hypot(i,j)/w' \
        -separate \
        -strip \
        "$map_p_radius"

    generate_curve_planks \
        "$base_straight_planks" \
        "$map_p_angle" \
        "$map_p_radius" \
        "$base_curve_planks"

    generate_curve_rails \
        "$base_straight_rails" \
        "$map_p_angle" \
        "$map_p_radius" \
        "$base_curve_rails"
}

generate_curve_planks()
{
    if [ "$#" -ne 4 ]
    then
        echo "Usage: generate_curve_planks <base_straight_planks_filepath.png> <map_p_angle_filepath.png> <map_p_radius_filepath.png> <base_curve_planks_output_filepath>"
        exit 1
    fi

    base_straight_planks="$1"
    map_p_angle="$2"
    map_p_radius="$3"
    base_curve_planks="$4"

    log "Generating base curve planks..."

    convert "$base_straight_planks" \
        "$map_p_angle" \
        "$map_p_radius" \
        -channel RGBA \
        -interpolate integer \
        -fx 'p{u[1].g*w,u[2].g*h}' \
        -rotate 90 \
        -strip \
        "$base_curve_planks"

    log "Saved      base curve planks to $base_curve_planks"
}

generate_curve_rails()
{
    if [ "$#" -ne 4 ]
    then
        echo "Usage: generate_curve_rails <base_straight_rails_filepath.png> <map_p_angle_filepath.png> <map_p_radius_filepath.png> <base_curve_rails_output_filepath>"
        exit 1
    fi

    base_straight_rails="$1"
    map_p_angle="$2"
    map_p_radius="$3"
    base_curve_rails="$4"

    log "Generating base curve rails..."
    
    height="$(identify -ping -format '%h' "$base_straight_rails")"

    # -nearest-neighbor is offset
    # -interpolate integer matches the rails better after a slight modification
    # could use the following, however that would generate a larger images
    # input \( input \( -clone -transpose \) -composite \) \( -size 64x64 xc: -draw 'rectangle 0,1 62,64' \) -compose Src
    # the following was also an option that wasn't investigated
    #    -channel alpha \
    #    -threshold 20% \
    #    +channel \
    # -channel RGBA and .g is needed to handle transparent images
    convert "$base_straight_rails" \
        "$map_p_angle" \
        "$map_p_radius" \
        -channel RGBA \
        -interpolate integer \
        -fx 'p{u[1].g*w,u[2].g*h}' \
        -compose copy \
        \( "$base_straight_rails" -crop "1x${height}+0+0" -transpose \) \
        -composite \
        \( "$base_straight_rails" -crop "1x${height}+0+0" \) \
        -composite \
        -rotate 90 \
        -strip \
        "$base_curve_rails"

    log "Saved      base curve rails to $base_curve_rails"
}

generate_straight_connection()
{
    if [ "$#" -ne 4 ]
    then
        echo "Usage: generate_straight_connection <height> <width> <connection_hex_color> <straight_connection_output_filepath>"
        exit 1
    fi

    height="$1"
    width="$2"
    color_connection="$3"
    base_straight_connection="$4"

    log "Generating base straight connection..."

    height_original="64"
    width_original="64"

    center_rail_original="28"
    center_rail_offset_from_center_ratio="( ( $height_original / 2 - $center_rail_original ) / $height_original )"
    center_rail_offset_from_center="( $center_rail_offset_from_center_ratio * $height - 0.5 )"

    rail_center_y="$(echo "scale=6; ( $height / 2 - $center_rail_offset_from_center)" | bc)"

    rail_width_original="3"
    rail_width_to_size_ratio="( $rail_width_original / $width_original )"
    rail_width="$(echo "scale=6; ( $rail_width_to_size_ratio * $height )" | bc)"

    connection_width="$(echo "scale=6; ( ( $rail_width / 2 + $center_rail_offset_from_center ) * 2)" | bc)"
    connection_center_y="$(echo "scale=6; ( $height / 2 - 0.5 )" | bc)"

    convert \
        -size "${width}x${height}" \
        canvas:none \
        -stroke "$color_connection" \
        -strokewidth "$connection_width" \
        +antialias \
        -draw "path 'M 0,$connection_center_y l $width,0'" \
        -strip \
        "$base_straight_connection"

    log "Saved      base straight connnection to $base_straight_connection"
}

generate_curve_connection()
{
    if [ "$#" -ne 2 ]
    then
        echo "Usage: generate_curve_connection <straight_connection_filepath.png> <curve_connection_output_filepath>"
        exit 1
    fi

    base_straight_connection="$1"
    base_curve_connection="$2"

    log "Generating curve connection..."

    map_p_angle="$(mktemp).png"
    map_p_radius="$(mktemp).png"

    image_size="$(identify -ping -format '%w %h' "$base_straight_connection")"
    width=${image_size% *}
    height=${image_size#* }

    convert \
        -size "${width}x${height}" \
        canvas: \
        -channel G \
        -fx 'atan((j+0.5)/(i+0.5))*2/pi' \
        -separate \
        -strip \
        "$map_p_angle"

    convert \
        -size "${width}x${height}" \
        canvas: \
        -channel G \
        -fx '1-hypot(i,j)/w' \
        -separate \
        -strip \
        "$map_p_radius"

    convert "$base_straight_connection" \
        "$map_p_angle" \
        "$map_p_radius" \
        -channel RGBA \
        -interpolate integer \
        -fx 'p{u[1].g*w,u[2].g*h}' \
        -compose copy \
        \( "$base_straight_connection" -crop "1x${height}+0+0" -transpose \) \
        -composite \
        \( "$base_straight_connection" -crop "1x${height}+0+0" \) \
        -composite \
        -rotate 90 \
        -strip \
        "$base_curve_connection"
    log "Saved      curve connection to $base_curve_connection"
}

generate_from_csv()
{
    if [ "$#" -ne 8 ]
    then
        echo "Usage: generate_from_csv <tiles.csv> <base_straight_planks.png> <base_straight_rails.png> <base_curve_planks.png> <base_curve_planks.png> <base_straight_connection.png> <base_curve_connection.png> <output_directory>"
        exit 1
    fi

    csv_file="$1"
    base_straight_planks="$2"
    base_straight_rails="$3"
    base_curve_planks="$4"
    base_curve_rails="$5"
    base_straight_connection="$6"
    base_curve_connection="$7"
    output_directory="$8"

    # removes header and types
    # add a newline if it doesn't already exist
    # removes carriage returns that break the last variable
    # remove commas in Overlays, ensuring to to the 3 part first
    cat "$csv_file" \
        | sed 2d \
        | sed -e '$a\' \
        | sed 's/\r//g' \
        | sed 's/"\([^,]*\), \([^,]*\), \([^"]*\)"/\1 \2 \3/' \
        | sed 's/"\([^,]*\), \([^"]*\)"/\1 \2/' \
        | while \
            IFS="," \
            read -r \
                abbreviation \
                name \
                color \
                group \
                type \
                filename \
                id \
                tmx_id \
                group_id \
                height \
                x \
                y \
                connection_color \
                overlays \
                speed \
                branching \
                branches \
                vertical \
                horizontal \
                up_right \
                down_left \
                down_right \
                up_left \
                up \
                right \
                down \
                left
    do
        if [ -z "$overwrite" -a -f "$output_directory/$filename" ]
        then
            continue
        elif [ "$group" = "Environment" ]
        then
            generate_environment \
                "$size" \
                "$color" \
                "$up_right" \
                "$down_left" \
                "$down_right" \
                "$up_left" \
                "$output_directory/$filename"
        elif [ "$group" = "Location" ]
        then
            generate_location \
                "$base_straight_planks" \
                "$base_straight_rails" \
                "$color" \
                "$abbreviation" \
                "$output_directory/$filename"
        elif [ "$group" = "Track" ]
        then
            generate_track \
                "$base_straight_planks" \
                "$base_straight_rails" \
                "$base_curve_planks" \
                "$base_curve_rails" \
                "$vertical" \
                "$horizontal" \
                "$up_right" \
                "$down_left" \
                "$down_right" \
                "$up_left" \
                "$color" \
                "$output_directory/$filename"
        elif [ "$group" = "Connection" ]
        then
            generate_connection \
                "$base_straight_connection" \
                "$base_curve_connection" \
                "$vertical" \
                "$horizontal" \
                "$up_right" \
                "$down_left" \
                "$down_right" \
                "$up_left" \
                "$color" \
                "$output_directory/$filename"
        fi
    done
}

generate_environment()
{
    if [ "$#" -ne 7 ]
    then
        echo "Usage: generate_environment
    <size>
    <environment_hex_color>
    <has up_right shape (TRUE|FALSE)>
    <has down_left shape (TRUE|FALSE)>
    <has down_right shape (TRUE|FALSE)>
    <has up_left shape (TRUE|FALSE)>
    <environment_output_filepath>"
        exit 1
    fi

    size="$1"
    color="$2"
    up_right="$3"
    down_left="$4"
    down_right="$5"
    up_left="$6"
    filename="$7"

    log -n "Generating environment $filename..."

    height="$size"
    width="$size"
    shape_opacity="0.2"

    shape_radius="$(echo "scale=6; ( $size / 8 )" | bc)"
    offset="( $size / 4 )"
    small_position="$(echo "scale=6; ( $offset - 0.5 )" | bc)"
    big_position="$(echo "scale=6; ( $size - $offset - 0.5 )" | bc)"

    paths="fill-opacity $shape_opacity "

    if [ "$up_left" = "TRUE" ]
    then
        x_position="$small_position"
        y_position="$small_position"
        add_environment_shape_path "$x_position" "$y_position" "$shape_radius"
    fi

    if [ "$down_left" = "TRUE" ]
    then
        x_position="$small_position"
        y_position="$big_position"
        add_environment_shape_path "$x_position" "$y_position" "$shape_radius"
    fi

    if [ "$down_right" = "TRUE" ]
    then
        x_position="$big_position"
        y_position="$big_position"
        add_environment_shape_path "$x_position" "$y_position" "$shape_radius"
    fi

    if [ "$up_right" = "TRUE" ]
    then
        x_position="$big_position"
        y_position="$small_position"
        add_environment_shape_path "$x_position" "$y_position" "$shape_radius"
    fi

    convert \
        -size "${height}x${width}" \
        canvas:"$color" \
        +antialias \
        -fill white \
        -draw "$paths" \
        -strip \
        "$filename"

    log " Done!"
}

add_environment_shape_path()
{
    if [ "$#" -ne 3 ]
    then
        echo "Usage: add_environment_shape_path <x_position> <y_position> <shape_radius>"
        exit 1
    fi

    if [ -z "$paths" ]
    then
        echo "The 'paths' variable can't be empty."
        exit 1
    fi

    x_position="$1"
    y_position="$2"
    shape_radius="$3"

    path="path 'M $x_position,$y_position l 0,-$shape_radius $shape_radius,$shape_radius -$shape_radius,$shape_radius -$shape_radius,-$shape_radius $shape_radius,-$shape_radius'"
    paths="$paths $path"
}

generate_location()
{
    if [ "$#" -ne 5 ]
    then
        echo "Usage: generate_location <base_straight_planks.png> <base_straight_rails.png> <location_hex_color> <location_text> <location_output_filepath>"
        exit 1
    fi

    base_straight_planks="$1"
    base_straight_rails="$2"
    color="$3"
    text="$4"
    filename="$5"

    log -n "Generating location $filename..."

    # .5 is needed to be used to get the right circle size, transposing didn't work.
    # pointsize is needed to be used as specifying a boundary size made less font bigger
    # composite is needed to draw the text
    convert \
        -background "$color" \
        +antialias \
        "$base_straight_planks" \
        \( "$base_straight_planks" -rotate 90 \) \
        "$base_straight_rails" \
        \( "$base_straight_rails" -rotate 90 \) \
        -fill white \
        -draw 'circle 31.5,31.5 31.5,47.5' \
        -layers flatten \
        -pointsize 17 \
        -background none \
        -gravity center \
        -font "Liberation-Serif-Bold" \
        -fill "$color" \
        label:"$text" \
        -composite \
        -strip \
        "$filename"

    log " Done!"
}

generate_track()
{
    if [ "$#" -ne 12 ]
    then
        echo "Usage: generate_track
    <base_straight_planks.png>
    <base_straight_rails.png>
    <base_curve_planks.png>
    <base_curve_rails.png>
    <is vertical (TRUE|FALSE)>
    <is horizontal (TRUE|FALSE)>
    <is up_right (TRUE|FALSE)>
    <is down_left (TRUE|FALSE)>
    <is down_right (TRUE|FALSE)>
    <is up_left (TRUE|FALSE)>
    <background_hex_color>
    <track_output_filepath>"
        exit
    fi

    base_straight_planks="$1"
    base_straight_rails="$2"
    base_curve_planks="$3"
    base_curve_rails="$4" # swapping these overlaps, but only half of the time?
    vertical="$5"
    horizontal="$6"
    up_right="$7"
    down_left="$8"
    down_right="$9"
    up_left="${10}"
    color="${11}"
    filename="${12}"

    log -n "Generating track $filename..."

    # to reset the variables
    horizontal_planks=""
    horizontal_rails=""

    vertical_planks=""
    vertical_rails=""

    up_right_planks=""
    up_right_rails=""

    down_left_planks=""
    down_left_rails=""

    down_right_planks=""
    down_right_rails=""

    up_left_planks=""
    up_left_rails=""

    
    if [ "$horizontal" = "TRUE" ]
    then
        horizontal_planks="$base_straight_planks"
        horizontal_rails="$base_straight_rails"
    fi

    if [ "$vertical" = "TRUE" ]
    then
        # bracketing the rotations makes them singular
        vertical_planks="( $base_straight_planks -rotate 90 )"
        vertical_rails="( $base_straight_rails -rotate 90 )"
    fi

    if [ "$up_right" = "TRUE" ]
    then
        up_right_planks="$base_curve_planks"
        up_right_rails="$base_curve_rails"
    fi

    if [ "$down_left" = "TRUE" ]
    then
        down_left_planks="( $base_curve_planks -rotate 180 )"
        down_left_rails="( $base_curve_rails -rotate 180 )"
    fi

    if [ "$down_right" = "TRUE" ]
    then
        down_right_planks="( $base_curve_planks -rotate 90 )"
        down_right_rails="( $base_curve_rails -rotate 90 )"
    fi

    if [ "$up_left" = "TRUE" ]
    then
        up_left_planks="( $base_curve_planks -rotate 270 )"
        up_left_rails="( $base_curve_rails -rotate 270 )"
    fi

    planks="
        $horizontal_planks 
        $vertical_planks 
        $up_right_planks 
        $down_left_planks 
        $down_right_planks 
        $up_left_planks"
 
         
    rails="
        $horizontal_rails 
        $vertical_rails 
        $up_right_rails 
        $down_left_rails 
        $down_right_rails 
        $up_left_rails"

    convert \
        -background "$color" \
        $planks \
        $rails \
        -layers flatten \
        -strip \
        "$filename"

    log " Done!"
}

generate_connection()
{
    if [ "$#" -ne 10 ]
    then
        echo "Usage: generate_connection
    <base_straight_connection.png>
    <base_curve_connection.png>
    <is vertical (TRUE|FALSE)>
    <is horizontal (TRUE|FALSE)>
    <is up_right (TRUE|FALSE)>
    <is down_left (TRUE|FALSE)>
    <is down_right (TRUE|FALSE)>
    <is up_left (TRUE|FALSE)>
    <connection_hex_color>
    <connection_output_filepath>"
        exit
    fi

    base_straight_connection="$1"
    base_curve_connection="$2" # swapping these overlaps, but only half of the time?
    vertical="$3"
    horizontal="$4"
    up_right="$5"
    down_left="$6"
    down_right="$7"
    up_left="$8"
    color="$9"
    filename="${10}"

    log -n "Generating track $filename..."

    # to reset the variables
    horizontal_connection=""
    vertical_connection=""
    up_right_connection=""
    down_left_connection=""
    down_right_connection=""
    up_left_connection=""

    
    if [ "$horizontal" = "TRUE" ]
    then
        horizontal_connection="$base_straight_connection"
    fi

    if [ "$vertical" = "TRUE" ]
    then
        # bracketing the rotations makes them singular
        vertical_connection="( $base_straight_connection -rotate 90 )"
    fi

    if [ "$up_right" = "TRUE" ]
    then
        up_right_connection="$base_curve_connection"
    fi

    if [ "$down_left" = "TRUE" ]
    then
        down_left_connection="( $base_curve_connection -rotate 180 )"
    fi

    if [ "$down_right" = "TRUE" ]
    then
        down_right_connection="( $base_curve_connection -rotate 90 )"
    fi

    if [ "$up_left" = "TRUE" ]
    then
        up_left_connection="( $base_curve_connection -rotate 270 )"
    fi

    connections="
        $horizontal_connection 
        $vertical_connection 
        $up_right_connection 
        $down_left_connection 
        $down_right_connection 
        $up_left_connection"

    convert \
        -background none \
        $connections \
        -layers flatten \
        -channel RGB \
        canvas:"$color" \
        -clut \
        -strip \
        "$filename"

    log " Done!"
}

main $@

