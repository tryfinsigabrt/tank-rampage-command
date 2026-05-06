import sys
from pathlib import Path

def get_top_files(directory, top_n=10):
    file_list = []
    
    # Path.rglob("*") recursively finds all files
    path_obj = Path(directory)
    
    print(f"Scanning: {path_obj.absolute()}")
    
    for file in path_obj.rglob("*"):
        try:
            # Skip directories and symlinks to avoid double-counting or errors
            if file.is_file() and not file.is_symlink():
                size = file.stat().st_size
                file_list.append((size, str(file)))
        except (PermissionError, FileNotFoundError):
            # Skip files that are locked or deleted during scan
            continue

    # Sort by size in descending order
    file_list.sort(key=lambda x: x[0], reverse=True)

    print(f"\n--- Top {top_n} Largest Files ---")
    for i, (size, path) in enumerate(file_list[:top_n], 1):
        # Convert bytes to a readable format
        if size > 1024**3:
            size_str = f"{size / 1024**3:.2f} GB"
        elif size > 1024**2:
            size_str = f"{size / 1024**2:.2f} MB"
        else:
            size_str = f"{size / 1024:.2f} KB"
            
        print(f"{i:>2}. [{size_str:<10}] {path}")

if __name__ == "__main__":
# Check if a path was provided, otherwise default to current directory
    target_folder = sys.argv[1] if len(sys.argv) > 1 else "."
    get_top_files(target_folder)