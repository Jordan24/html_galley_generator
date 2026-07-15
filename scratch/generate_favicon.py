import os
from PIL import Image

def generate_icons():
    source_path = 'assets/ja_logo_ribbon.jpg'
    if not os.path.exists(source_path):
        print(f"Error: Source image {source_path} not found.")
        return

    # Open the source image
    with Image.open(source_path) as img:
        print(f"Loaded source image {source_path} of size {img.size}")
        
        # Determine filter to use
        try:
            resampling_filter = Image.Resampling.LANCZOS
        except AttributeError:
            resampling_filter = Image.LANCZOS

        # Target definitions: (destination_path, size, mode)
        targets = [
            ('web/favicon.png', (32, 32), 'RGBA'),
            ('web/icons/Icon-192.png', (192, 192), 'RGB'),
            ('web/icons/Icon-512.png', (512, 512), 'RGB'),
            ('web/icons/Icon-maskable-192.png', (192, 192), 'RGBA'),
            ('web/icons/Icon-maskable-512.png', (512, 512), 'RGBA'),
        ]

        for dest_path, size, mode in targets:
            # Ensure output directory exists
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            
            # Resize image
            resized_img = img.resize(size, resampling_filter)
            
            # Convert to target mode if needed
            if resized_img.mode != mode:
                resized_img = resized_img.convert(mode)
                
            # Save the image
            resized_img.save(dest_path, 'PNG')
            print(f"Generated {dest_path} ({size[0]}x{size[1]}, {mode})")

if __name__ == '__main__':
    generate_icons()
