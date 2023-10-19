#!/bin/sh

user="asterisk"
dry_run="1"
rc_num=""

if [[ $# -eq 0 ]] ; then
    echo 'Release script requires at leaset 2 arguments:'
    echo '1. Release Name: Release name to create dahdi release. This parameter is mandatory'
    echo '2. Dry Run: If user just want to run for testing purpose'
    echo '3. Beta Release number if its is a beta release'
    echo '4. User: User from where dahdi files is getting downloaded.'

    exit 1
fi

if [ -d release ]; then
	date=`date`
	mv release release-$date
fi

if [ "w$1" == "w" ]; then
    echo "Please enter valid release name as first argument"
    exit 1
else
    if [ "w$3" == "w" ]; then
        rc_num=""
    else
        if [ $3 == 0 ]; then
            rc_num=""
        else
            rc_num="-rc$3"
        fi
    fi
    branch_name=$1
    release_name=$1$rc_num
    echo "$release_name PUSHKAR"
fi

if [ "w$2" == "w" ]; then
    dry_run="1"
else
    dry_run="0"
fi

if [ "w$4" == "w" ]; then
    user="asterisk"
else
    user=$4
fi

echo "Running in mode $dry_run for creating DAHDI Release $release_name from user $user with branch $branch_name with token as $5."

mkdir release
cd release

echo "Cloning DAHDI Linux"
git clone git@github.com:$user/dahdi-linux.git
exit



echo "Creating DAHDI Linux Complete"
linux_complete_name="dahdi-linux-complete-"$release_name"+"$release_name
echo "$linux_complete_name"
mkdir dahdi-linux-complete-$release_name+$release_name
cp -rfL ../dahdi-linux-complete-common/* dahdi-linux-complete-$release_name+$release_name/.

echo "Cloning DAHDI Linux"
git clone git@github.com:$user/dahdi-linux.git
cd dahdi-linux
git pull origin master

existed_in_remote=$(git ls-remote --heads origin ${branch_name})

echo "Copying Dahdi linux in to linux folder of $linux_complete_name"
git checkout-index -a -f --prefix=/root/Projects/dahdi-release/release/$linux_complete_name/linux/
echo $release_name > /root/Projects/dahdi-release/release/$linux_complete_name/linux/.version

echo "Copying Dahdi linux in to Dahdi-linux-$release_name folder"
git checkout-index -a -f --prefix=/root/Projects/dahdi-release/release/dahdi-linux-$release_name/
echo $release_name > /root/Projects/dahdi-release/release/dahdi-linux-$release_name/.version

echo "Changing directory to linux folder of $$linux_complete_name"
cd ../$linux_complete_name/linux
make install-firmware firmware-loaders
cd ../..

echo "Cloning DAHDI Tools"
git clone git@github.com:$user/dahdi-tools.git
cd dahdi-tools
git pull origin master
existed_in_remote=""

existed_in_remote=$(git ls-remote --heads origin ${branch_name})

echo "Copying Dahdi tools in to linux folder of $linux_complete_name"
git checkout-index -a -f --prefix=/root/Projects/dahdi-release/release/$linux_complete_name/tools/
echo $release_name > /root/Projects/dahdi-release/release/$linux_complete_name/tools/.version

echo "Copying Dahdi tools in to dahdi-tools-$release_name folder"
git checkout-index -a -f --prefix=/root/Projects/dahdi-release/release/dahdi-tools-$release_name/
echo $release_name > /root/Projects/dahdi-release/release/dahdi-tools-$release_name/.version


cd ..

echo "Creating DAHDI Linux Complete Release"
echo "Creating DAHDI Linux Complete Tar Ball"
tar -czvf $linux_complete_name.tar.gz $linux_complete_name

echo "Creating DAHDI Linux Complete Tar Ball Sha1 and verify the same"
sha1sum $linux_complete_name.tar.gz > $linux_complete_name.tar.gz.sha1
sha1sum -c $linux_complete_name.sha1

echo "Signing in DAHDI Linux Complete Tar Ball and verify the same"
gpg --armor --detach-sign --output $linux_complete_name.tar.gz.asc $linux_complete_name.tar.gz
gpg --verify $linux_complete_name.tar.gz.asc


echo "Creating DAHDI Linux Release"
echo "Creating DAHDI Linux Tar Ball"
tar -czvf dahdi-linux-$release_name.tar.gz dahdi-linux-$release_name

echo "Creating DAHDI Linux Tar Ball Sha1 and verify the same"
sha1sum dahdi-linux-$release_name.tar.gz > dahdi-linux-$release_name.tar.gz.sha1
sha1sum -c dahdi-linux-$release_name.tar.gz.sha1

echo "Signing in DAHDI Linux Tar Ball and verify the same"
gpg --armor --detach-sign --output dahdi-linux-$release_name.tar.gz.asc dahdi-linux-$release_name.tar.gz
gpg --verify dahdi-linux-$release_name.tar.gz.asc


echo "Creating DAHDI Tools Release"
tar -czvf dahdi-tools-$release_name.tar.gz dahdi-tools-$release_name

echo "Creating DAHDI Tools Tar Ball Sha1 and verify the same"
sha1sum dahdi-tools-$release_name.tar.gz > dahdi-tools-$release_name.tar.gz.sha1
sha1sum -c dahdi-tools-$release_name.tar.gz.sha1

echo "Signing in DAHDI Tools Tar Ball and verify the same"
gpg --armor --detach-sign --output dahdi-tools-$release_name.tar.gz.asc dahdi-tools-$release_name.tar.gz
gpg --verify dahdi-tools-$release_name.tar.gz.asc
