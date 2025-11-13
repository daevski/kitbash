gh_username=daevski
repo_name=kitbash
working_dir="$HOME/Downloads"

git clone https://github.com/$gh_username/$repo_name $working_dir/$repo_name
chmod +x $working_dir/$repo_name/kit-start.sh
echo "alias kit=$working_dir/$repo_name/kit-start.sh" >> $HOME/.bashrc

echo "Setup complete! Alias 'kit' added to ~/.bashrc"
echo ""
echo "To use the alias now, run:"
echo "  source ~/.bashrc"
echo ""
echo "Or simply open a new terminal window."
