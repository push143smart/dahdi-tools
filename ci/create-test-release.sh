#!/bin/sh

set -e

user="asterisk"
project="dahdi-linux"
dry_run="1"
rc_num=""
github_token=""

download_github_project() {
        project_name=$1
        echo "Cloning $project_name Linux"

        if [ "w$github_token" != "w" ]; then
                git clone https://$github_token@github.com/$user/${project_name}.git
        else
                git clone git@github.com:$user/${project_name}.git
        fi
}

check_branch_exist() {
        project_name=$1

        existed_in_remote=$(git ls-remote --heads origin ${branch_name})

        echo $existed_in_remote
}

create_checkout_github_project_branch() {
        project_name=$1

        if [ ! -d $project_name ]; then
                ls
                echo "$project_name clone failed!!"
                exit
        fi

        cd $project_name
        git pull origin master

        branch_present=$( check_branch_exist $project_name )

        if [ "$dry_run" == "0" ]; then
                if [[ -z ${branch_present} ]]; then
                        echo "Creating branch $branch_name for $project_name"
                        git remote -v
                        if [ "$project_name" == "dahdi-tools" ]; then
                                git push origin test-release:refs/heads/$branch_name
                        else
                                git push origin master:refs/heads/$branch_name
                        fi
                fi

                git fetch origin
                echo "Checking out to branch $branch_name"
                git checkout -b $branch_name origin/$branch_name
                git pull origin $branch_name
        fi
}

create_tag_github_project() {
        project_name=$1

        if [ "$dry_run" == "0" ]; then
                if [ $(git tag -l v$release_name) ];then
                        echo "Tag v$release_name already present for $project_name"
                else
                        echo "Creating Tag v$release_name for $project_name"
                        git tag -m "Tag v$release_name" -a v$release_name

                        git push origin v$release_name
                fi
        fi
}

create_project_release_tar() {
        project_name=$1

        echo "Creating $project_name Release"

        echo "Copying Dahdi linux in to $project_name-$release_name folder"
        git checkout-index -a -f --prefix=../$project_name-$release_name/
        echo $release_name > ../$project_name-$release_name/.version

        cd ..

        echo "Creating $project_name Tar Ball"
        tar -czvf $project_name-$release_name.tar.gz $project_name-$release_name

        echo "Creating $project_name-$release_name.tar.gz.sha1 and verify the same"
        sha1sum $project_name-$release_name.tar.gz > $project_name-$release_name.tar.gz.sha1
        sha1sum -c $project_name-$release_name.tar.gz.sha1

        echo "Creating $project_name-$release_name.tar.gz.sha256 and verify the same"
        sha256sum $project_name-$release_name.tar.gz > $project_name-$release_name.tar.gz.sha256
        sha256sum -c $project_name-$release_name.tar.gz.sha256

        echo "Creating $project_name-$release_name.tar.gz.md5 and verify the same"
        md5sum $project_name-$release_name.tar.gz > $project_name-$release_name.tar.gz.md5
        md5sum -c $project_name-$release_name.tar.gz.md5

        echo "Signing in $project_name-$release_name.tar.gz and verify the same"
        gpg --armor --detach-sign --output $project_name-$release_name.tar.gz.asc $project_name-$release_name.tar.gz
        gpg --verify $project_name-$release_name.tar.gz.asc
}

import_gpg_key() {
        if [ "w$gpg_priv_token" != "w" ]; then
                echo "PUSHKAR: $gpg_priv_token"
                echo "$gpg_priv_token" > import_gpg.key
                cat import_gpg.key
                gpg --import import_gpg.key
                gpg --list-keys
                rm -rf import_gpg.key
        else
                resp_code=`curl -s -o response.txt -w "%{http_code}" -L \
                          -H "Accept: application/vnd.github+json" \
                          -H "Authorization: Bearer $github_token" \
                          -H "X-GitHub-Api-Version: 2022-11-28" \
                          https://api.github.com/user/gpg_keys`

                if [ "$resp_code" == "200" ] || [ "$resp_code" == "201" ] || [ "$resp_code" == "202" ]; then
                        cat response.txt | grep -oP "(?<=raw_key\":)[^","]*"  | awk -F\" '{print $2}' | sed 's/\\r\\n/\n/g' |  sed -z 's/\(.*\)\n$/\1/' > import_gpg.key
                        cat import_gpg.key
                        gpg --import import_gpg.key
                        gpg --list-keys
                        rm -rf import_gpg.key
                else
                        echo "Not able to import gpgkey with resp_code as $resp_code"
                fi
        fi
}

create_github_release() {
        project_name=$1

        resp_code=`curl -s -o response.txt -w "%{http_code}" -L \
                  -X POST \
                  -H "Accept: application/vnd.github+json" \
                  -H "Authorization: Bearer $github_token" \
                  -H "X-GitHub-Api-Version: 2022-11-28" \
                  https://api.github.com/repos/$user/$project_name/releases \
                  -d '{"tag_name":"v'$release_name'","target_commitish":"'$branch_name'","name":"v'$release_name'","body":"This is Pushkar Test Release","draft":false,"prerelease":true,"generate_release_notes":false}'`

        if [ "$resp_code" == "200" ] || [ "$resp_code" == "201" ] || [ "$resp_code" == "202" ]; then
                id_token=`cat response.txt | grep -oP "(?<=id\":)[^","]*"  | head -n 1 | tr -d ' '`
                echo $id_token
        else
                id_token=0
                echo "Invalid response code $resp_code while creating release"
                echo "Github $project_name Release $release_name failed"
                exit
        fi

        rm -rf response.txt
}

upload_github_release_asset() {
        project_name=$1
        id_token=$2

        echo "PUSHKAR upload_github_release_asset: $id_token"
        files=`ls *tar.gz* | tr -d ' '`
        IFS=$'\n'

        echo "PUSHKAR upload_github_release_asset: $files"
        for file_name in $files; do
                echo "PUSHKAR : $file_name"
                resp_code=`curl -s -o response.txt -w "%{http_code}" -L \
                          -X POST \
                          -H "Accept: application/vnd.github+json" \
                          -H "Authorization: Bearer $github_token" \
                          -H "X-GitHub-Api-Version: 2022-11-28" \
                          -H "Content-Type: application/octet-stream" \
                          "https://uploads.github.com/repos/$user/$project_name/releases/$id_token/assets?name=$file_name" \
                          --data-binary "@$file_name"`

                if [ "$resp_code" == "200" ] || [ "$resp_code" == "201" ] || [ "$resp_code" == "202" ]; then
                        echo "Release file $file_name successfully uploaded"
                else
                        echo "Invalid response code $resp_code while uploading release file $file_name"
                fi

                rm -rf response.txt
        done
}

if [[ $# -eq 0 ]] ; then
    echo 'Release script requires all below inputs:'
    echo '1. Product Name: Name of Product for whch eleas needs to be created. This parameter is mandatory'
    echo '2. Release Name: Release name to create dahdi release. This parameter is mandatory'
    echo '3. Dry Run: If user just want to run for testing purpose'
    echo '4. Beta Release number if its is a beta release'
    echo '5. User: User from where dahdi files is getting downloaded.'
    echo '6. Provide User Github token. Thi is Optional.'

    exit 1
fi

if [ -d release ]; then
        date=`date +'%d-%m-%Y:%R'`
        mv release "release-$date"
fi

if [ "w$1" == "w" ]; then
        project="dahdi-linux"
else
        project=$1
fi

if [ "w$2" == "w" ]; then
        echo "Please enter valid release name as seconds argument"
        exit 1
else
        if [ "w$4" == "w" ]; then
                rc_num=""
        else
                if [ $4 == 0 ]; then
                    rc_num=""
                else
                        rc_num="-rc$4"
                fi
        fi
        branch_name=$2
        release_name=$2$rc_num
fi

if [ "w$3" == "w" ]; then
        dry_run="1"
else
        dry_run="0"
fi

if [ "w$5" == "w" ]; then
        user="asterisk"
else
        user=$5
fi

if [ "w$6" != "w" ]; then
        github_token=$6
fi

if [ "w$6" != "w" ]; then
        gpg_priv_token=$7
fi
echo "Setting up git global config....."
git config --global user.email "psingh@sangoma.com"
git config --global user.name "Pushkar Singh"

echo "Setting up user gpg key and $7"
import_gpg_key

echo "Setting up user ssh keys"


echo "Creating $project Release $release_name from branch $branch_name of $user"

mkdir release
ls -lrt

cd release

if [ "$project" == "dahdi-linux-complete" ]; then
        echo "Creating DAHDI Linux Complete"
        linux_complete_name="dahdi-linux-complete-"$release_name"+"$release_name
        echo "$linux_complete_name"
        mkdir dahdi-linux-complete-$release_name+$release_name
        ls -lrt
        #Pushkar to come back in here
        #cp -rfL ../../dahdi-linux-complete-common/* dahdi-linux-complete-$release_name+$release_name/.

#Download project
        download_github_project dahdi-linux
#Push new branch / change new branch
        create_checkout_github_project_branch dahdi-linux
#Create Tag
        create_tag_github_project dahdi-linux

#Copying Dahdi-linux in to dahdi-linux-complete
        echo "Copying Dahdi linux in to linux folder of $linux_complete_name"
        git checkout-index -a -f --prefix=../$linux_complete_name/linux/
        echo $release_name > ../$linux_complete_name/linux/.version

        echo "Changing directory to linux folder of $linux_complete_name"
        cd ../$linux_complete_name
        ls -lrt
        cd linux
        make install-firmware firmware-loaders
        cd ../../dahdi-linux
        ls -lrt
        exit
        
#Create Dahdi-linux release tar ball
        create_project_release_tar dahdi-linux

#Download project
        download_github_project dahdi-tools
#Push new branch / change new branch
        create_checkout_github_project_branch dahdi-tools
#Create Tag
        create_tag_github_project dahdi-tools

#Copying Dahdi-tools in to dahdi-linux-complete
        echo "Copying Dahdi tools in to linux folder of $linux_complete_name"
        git checkout-index -a -f --prefix=../$linux_complete_name/tools/
        echo $release_name > ../$linux_complete_name/tools/.version

#Create Dahdi-tools release tar ball
        create_project_release_tar dahdi-tools

#Create Dahdi-linux-complete release tar ball
        echo "Creating DAHDI Linux Complete Release"
        echo "Creating DAHDI Linux Complete Tar Ball"
        tar -czvf $linux_complete_name.tar.gz $linux_complete_name

        echo "Creating DAHDI Linux Complete Tar Ball Sha1 and verify the same"
        sha1sum $linux_complete_name.tar.gz > $linux_complete_name.tar.gz.sha1
        sha1sum -c $linux_complete_name.tar.gz.sha1

        echo "Creating DAHDI Linux Complete Tar Ball Sha1 and verify the same"
        sha256sum $linux_complete_name.tar.gz > $linux_complete_name.tar.gz.sha256
        sha256sum -c $linux_complete_name.tar.gz.sha256

        echo "Creating DAHDI Linux Complete Tar Ball Sha1 and verify the same"
        md5sum $linux_complete_name.tar.gz > $linux_complete_name.tar.gz.md5
        md5sum -c $linux_complete_name.tar.gz.md5

        echo "Signing in DAHDI Linux Complete Tar Ball and verify the same"
        gpg --armor --detach-sign --output $linux_complete_name.tar.gz.asc $linux_complete_name.tar.gz
        gpg --verify $linux_complete_name.tar.gz.asc


#Create Release Candidate of that tag on Github and upload assests
        id_token=$( create_github_release dahdi-linux )
        echo "Github dahdi-linux Release Successfully created $id_token"
        upload_github_release_asset dahdi-linux $id_token

        id_token=""
#Create Release Candidate of that tag on Github and upload assests
        id_token=$( create_github_release dahdi-tools )
        echo "Github dahdi-tools Release Successfully created $id_token"
        upload_github_release_asset dahdi-tools $id_token

        id_token=""
#Create Release Candidate of that tag on Github and upload assests
#       id_token=$( create_github_release dahdi-linux-complete )
#       upload_github_release_asset dahdi-linux-complete $id_token
else
#Download project
        download_github_project $project

#Push new branch / change new branch
        create_checkout_github_project_branch $project

#Create Tag
        create_tag_github_project $project

#Create Tar ball
        create_project_release_tar $project

#Create Release Candidate of that tag on Github
        id_token=$( create_github_release $project )
        echo "Github $project Release Successfully created $id_token"

#Upload Assests on Github release
        upload_github_release_asset $project $id_token
fi
