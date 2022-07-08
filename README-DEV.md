# WIP 

### How it works :
adding an app to the repo work like this :
In update-packages-in-repo.sh, add a line at the end :
```
create_packages name method project_home git_url api_option api_filter depandancies description pre_install_cmd post_install_cmd pre_remove_cmd post_remove_cmd pre_upgrade_cmd post_upgrade_cmd buildargs
```

1. create_packages is the name of the function
2. name is the you package will have in repo
3. method is the way the app will be added to repo, two methods are available
	- "std" will download the latest binary released from github and push to the repo
		- required args : api_url, api_filter
	- "git" will run a Golang container, clone the repo inside the container, git checkout to the latest tag and perform make commands
		- required args : git_url, api_option 