#!/bin/bash
#
# Script to download pretrained FastVLM models for the Flutter iOS app
# Based on Apple's ml-fastvlm get_pretrained_mlx_model.sh
#

set -e

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --model <size>    Model size to download: 0.5b, 1.5b, or 7b (default: 0.5b)"
    echo "  --dest <path>     Destination directory (default: ios/Runner/model)"
    echo "  --help            Show this help message"
    echo ""
    echo "Model sizes:"
    echo "  0.5b  - Small and fast, great for mobile devices where speed matters"
    echo "  1.5b  - Well balanced, great for larger devices where speed and accuracy matters"
    echo "  7b    - Fast and accurate, ideal for situations where accuracy matters over speed"
    echo ""
    echo "Example:"
    echo "  $0 --model 0.5b"
    echo "  $0 --model 1.5b --dest custom/path"
}

# Default values
model_size="0.5b"
dest_dir="ios/Runner/model"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            model_size="$2"
            shift 2
            ;;
        --dest)
            dest_dir="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Map model size to model name
case $model_size in
    "0.5b") model="llava-fastvithd_0.5b_stage3_llm.fp16" ;;
    "1.5b") model="llava-fastvithd_1.5b_stage3_llm.int8" ;;
    "7b") model="llava-fastvithd_7b_stage3_llm.int4" ;;
    *)
        echo "Error: Invalid model size '$model_size'"
        echo "Valid options: 0.5b, 1.5b, 7b"
        exit 1
        ;;
esac

echo "========================================"
echo "FastVLM Model Downloader for Flutter"
echo "========================================"
echo ""
echo "Model: FastVLM $model_size"
echo "Destination: $dest_dir"
echo ""

cleanup() { 
    rm -rf "$tmp_dir"
}

download_model() {
    # Download directory
    tmp_dir=$(mktemp -d)
    trap cleanup EXIT

    # Model paths
    base_url="https://ml-site.cdn-apple.com/datasets/fastvlm"
    zip_file="$model.zip"
    url="$base_url/$zip_file"

    # Create destination directory if it doesn't exist
    if [ ! -d "$dest_dir" ]; then
        echo "Creating destination directory: $dest_dir"
        mkdir -p "$dest_dir"
    elif [ "$(ls -A "$dest_dir" 2>/dev/null)" ]; then
        echo ""
        echo "Warning: Destination directory is not empty: $dest_dir"
        read -p "Do you want to clear it and continue? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$dest_dir"/*
        else
            echo "Aborted."
            exit 1
        fi
    fi

    echo ""
    echo "Downloading FastVLM $model_size model..."
    echo "URL: $url"
    echo ""

    # Download the model
    curl -L --progress-bar -o "$tmp_dir/$zip_file" "$url"

    if [ ! -f "$tmp_dir/$zip_file" ]; then
        echo "Error: Failed to download model"
        exit 1
    fi

    echo ""
    echo "Extracting model..."
    
    # Unzip the model
    unzip -q "$tmp_dir/$zip_file" -d "$tmp_dir"

    # Move files to destination
    mv "$tmp_dir/$model"/* "$dest_dir/"

    echo ""
    echo "========================================"
    echo "Download complete!"
    echo "========================================"
    echo ""
    echo "Model files saved to: $dest_dir"
    echo ""
    echo "Next steps:"
    echo "1. Open the project in Xcode"
    echo "2. Add the 'model' folder to your Runner target"
    echo "3. Build and run the app"
    echo ""
}

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but not installed"
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "Error: unzip is required but not installed"
    exit 1
fi

download_model
