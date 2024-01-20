#!/bin/bash

# Check if three arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 input_image width output.webp"
    exit 1
fi

# Assign arguments to variables
input_file=$1
width=$2
output_file=$3

# Check if vips is installed
if ! command -v vips &> /dev/null; then
    echo "libvips is required."
    exit 1
fi

# Calculate the scale for resizing
original_width=$(vipsheader -f Xsize "$input_file")
scale=$(echo "$width / $original_width" | bc -l)

# Resize the image
vips resize "$input_file" "${output_file%.webp}.png" "$scale"

# Define quality for WebP output (0-100, higher is better quality)
quality=90

# Convert the resized image to WebP format with specified quality
vips webpsave "${output_file%.webp}.png" "$output_file" --Q="$quality"

# Remove the temporary PNG file
rm "${output_file%.webp}.png"

echo "Conversion completed: '$output_file'"
