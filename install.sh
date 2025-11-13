gh_username=daevski
repo_name=kitbash
working_dir="$HOME/Downloads"
target_dir="$working_dir/$repo_name"

# Remove existing directory if it exists
if [ -d "$target_dir" ]; then
    echo "Removing existing $target_dir directory..."
    rm -rf "$target_dir"
fi

git clone https://github.com/$gh_username/$repo_name "$target_dir"
chmod +x "$target_dir/kit-start.sh"
echo "alias kit=$target_dir/kit-start.sh" >> $HOME/.bashrc

echo ""
echo "Setup complete! Alias 'kit' added to ~/.bashrc"
echo ""
echo "To use the alias now, run:"
echo "  source ~/.bashrc"
echo ""
echo "Or simply open a new terminal window."
