#!/bin/bash

echo -e "\033[0;32mDeploying updates to Coding...\033[0m"

# Build the project.
hugo -t nofancy # if using a theme, replace with `hugo -t <YOURTHEME>`

# Go To Public folder
cd public
# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
git push coding master

# Come Back up to the Project Root
cd ..