gh_username=daevski
repo_name=kitbash
working_dir="$HOME/Downloads"

git clone https://github.com/$gh_username/$repo_name $working_dir
chmod +x $working_dir/$repo_name/kit-start.sh
echo "alias kit=$working_dir/$repo_name/kit-start.sh" >> $HOME/.bashrc
source $HOME/.bashrc
echo "Alias 'kit' created been created for the kitbash core script: kit-start.sh; example 'kit hostname mypc'"
