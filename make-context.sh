#!/bin/bash

# based on:
# https://medium.com/@horaciochacn/github-repositories-as-context-for-claude-3-5-sonnet-accelerating-science-reproducibility-f9255a73aea4

# Extract repository name from URL
repo_name="NMRTools"

# Output file
output_file="${repo_name}_context.md"

# Remove the output file if it already exists
rm -f "$output_file"

# Function to process each file
process_file() {
    local file="$1"
    echo "Processing file: $file"
    echo "Path: $file" >> "$output_file"
    echo "" >> "$output_file"

    # Determine the file extension
    extension="${file##*.}"

    # Set the appropriate language for the code block
    case "$extension" in
        toml) language="toml" ;;
        md) language="" ;;
        jl) language="julia" ;;
        *) language="plaintext" ;;
    esac

    echo "\`\`\`$language" >> "$output_file"
    cat "$file" >> "$output_file"
    echo "\`\`\`" >> "$output_file"
    echo "" >> "$output_file"
    echo "-----------" >> "$output_file"
    echo "" >> "$output_file"
}

# Find files including subdirectories matching *.jl or *.md
# excluding pluto-workbooks, additional-docs directories, and make-context.sh file
# and call process_file
find . -type f \( -name "*.jl" -o -name "*.md" \) ! -path "./pluto-workbooks/*" ! -path "./test/*" ! -path "./additional-docs/*" ! -name "make-context.sh" |
    while read -r file; do
        process_file "$file"
    done


echo "Repository contents have been processed and combined into $output_file"