#!/bin/bash

# Remove temporary files
cleanup() {
    rm -rf /tmp/catchpoint_chrome* 2> /dev/null
}

cleanup

# Declare the associative array
declare -A chrome_versions=(
    ["120.0.6099.224.0"]="107M"
    ["108.0.5359.94.0"]="94M"
    ["97.0.4692.99.0"]="91M"
    ["89.0.4389.82.0"]="76M"
    ["87.0.4280.88.1"]="78M"
    ["85.0.4183.83.2"]="75M"
    ["75.0.3770.90.1"]="61M"
    ["71.0.3578.98.1"]="59M"
    ["66.0.3359.170.1"]="54.7M"
    ["63.0.3239.132.1"]="51.9M"
    ["59.0.3071.115.1"]="53M"
)

# Install necessary packages
install_packages() {
    echo "Installing Necessary Packages"
    local packages=("epel-release" "pv" "p7zip")
    for package in "${packages[@]}"; do
        if ! rpm -q $package > /dev/null; then
            if ! sudo yum --quiet -y install $package 2> /dev/null; then
                echo "Failed to install $package"
                exit 1
            fi
        fi
    done
    echo "Packages Installed Successfully"
}
install_packages

# Download and extract Chrome version
install_chrome_version() {
    local version=$1
    local size=$(printf "%.0f" $(echo "${chrome_versions[$version]%%M} * 1024 * 1024" | bc))
    local major_version=$(echo $version | cut -d'.' -f1)
    echo "Downloading Chrome Version $major_version"
    local download_success=0

    for i in {1..5}; do
        if sudo curl -sS --continue-at - "http://47.95.6.227/repo/chrome_versions/catchpoint_chrome_linux_$version.7z" | pv -s $size -b -p -t -e -r | sudo tee /tmp/catchpoint_chrome_linux_$version.7z > /dev/null; then
            download_success=1
            break
        else
            echo "Curl failed, retrying... (attempt $i)"
            sleep 5
        fi
    done

    if [ $download_success -eq 0 ]; then
        echo "Failed to download Chrome $version after 5 attempts"
        return 1
    fi

    for i in {1..5}; do
        if cd /tmp/ && sudo 7za x "/tmp/catchpoint_chrome_linux_$version.7z" > /dev/null; then
            break
        else
            echo "Extraction failed, retrying with wget... (attempt $i)"
            sleep 5
            rm -rf /tmp/catchpoint_chrome_linux_$version*
            if sudo wget "http://47.95.6.227/repo/chrome_versions/catchpoint_chrome_linux_$version.7z" -O /tmp/catchpoint_chrome_linux_$version.7z; then
                download_success=1
            else
                echo "wget failed, retrying... (attempt $i)"
                sleep 5
            fi
        fi
    done

    if [ $? -ne 0 ]; then
        echo "Failed to extract /tmp/catchpoint_chrome_linux_$version.7z after 5 attempts"
        return 1
    fi

    sleep 5
    sudo mkdir -p "/opt/3genlabs/hawk/syntheticnode/service/chrome/$version"
    sudo tar -xvf "/tmp/catchpoint_chrome_linux_$version.tar" -C "/opt/3genlabs/hawk/syntheticnode/service/chrome/$version" > /dev/null
    echo "Chrome $major_version Downloaded successfully"
    sudo chown -R serveruser:cp "/opt/3genlabs/hawk/syntheticnode/service/chrome/$version"
    cd "/opt/3genlabs/hawk/syntheticnode/service/chrome/$version" && sudo chown root:root chrome-sandbox && sudo chmod 4755 chrome-sandbox
    return 0
}

# Loop over the list and install each version
echo -e "\nChrome Downloading Status:\n"
for version in "${!chrome_versions[@]}"; do
    install_chrome_version "$version"
done

# Restart the Catchpoint Agent
echo ""
echo "Restarting Catchpoint Agent"
echo ""
if ! sudo catchpoint restart; then
    echo "Failed to restart Catchpoint Agent"
    exit 1
fi

# Cleanup
cleanup

# Remove the file Once the script execution completed
sudo rm /var/tmp/cn_allchromedeploy.sh 2> /dev/null 