#!/bin/bash

# Check if rsync is installed
if ! command -v rsync &> /dev/null
then
    echo ">>    rsync could not be found, trying to install it."
    sudo apt install rsync > /dev/null
    if [ $? -ne 0 ]; then
        apt install rsync > /dev/null
    fi
fi

# Check if inotify-tools is installed
if ! command -v inotifywait &> /dev/null
then
    echo ">>    inotify-tools could not be found, trying to install it."
    sudo apt install inotify-tools > /dev/null
    if [ $? -ne 0 ]; then
        apt install inotify-tools > /dev/null
    fi
fi

echo ">>    Enter the unique name of the sync service: "
read sync_service_name

echo ">>    Enter the path of the folder to sync: "
read folder_path

echo ">>    Enter the username of the remote server: "
read remote_username

echo ">>    Enter the IP address of the remote server: "
read remote_ip

echo ">>    Enter the port of the remote server: (leave empty if default)"
read remote_port

if [ -z "$remote_port" ]
then
    remote_port=22
fi

echo ">>    Generating ssh key pair for the sync service..."
ssh_key_name=auto_generated_sync_service_key-$sync_service_name-$(date +%s)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/$ssh_key_name -N "" > /dev/null

echo ">>    Registering the public key to the remote server..."
echo ">>    Enter the password of the remote server: "
ssh-copy-id -i ~/.ssh/$ssh_key_name.pub -p $remote_port $remote_username@$remote_ip

echo ">>    Enter the path of the folder on the remote server: "
read remote_folder_path

echo ">>    Enter the path of the .ignore file (leave empty if not needed): "
read ignore_file_path

echo ">>    Generating sync script..."
sync_script_name=sync-$sync_service_name.sh
echo "#!/bin/bash" > $sync_script_name
echo "rsync -avz --delete --exclude-from=$ignore_file_path -e "ssh -i ~/.ssh/$ssh_key_name -p $remote_port" $folder_path/ $remote_username@$remote_ip:$remote_folder_path" > $sync_script_name

echo "while true; do" >> $sync_script_name
echo "  inotifywait -r -e modify,create,delete $folder_path" >> $sync_script_name
if [ -z "$ignore_file_path" ]
then
    ignore_file_path=$folder_path/.ignore
else
    ignore_file_path=$ignore_file_path
fi
echo "  rsync -avz --delete --exclude-from=$ignore_file_path -e \"ssh -i ~/.ssh/$ssh_key_name -p $remote_port\" $folder_path/ $remote_username@$remote_ip:$remote_folder_path" >> $sync_script_name
echo "done" >> $sync_script_name

chmod +x $sync_script_name
echo ">>    Sync script generated: $sync_script_name"
