#!/bin/sh

CPSUPPDIR='/opt/catchpoint/etc'
SUPPDIR='/var/tmp/supplemental'
ANCHORDIR='/etc/pki/ca-trust/source/anchors'
SUPPCA=('https://www.apple.com/appleca/AppleIncRootCertificate.cer' \
'https://www.apple.com/certificateauthority/AppleComputerRootCertificate.cer' \
'https://www.apple.com/certificateauthority/AppleRootCA-G2.cer' \
'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer' \
'https://www.cisco.com/security/pki/certs/ciscoumbrellaroot.cer' \
'http://www.microsoft.com/pki/certs/MicRooCerAut2011_2011_03_22.crt' \
'https://www.microsoft.com/pkiops/certs/Microsoft%20ECC%20Product%20Root%20Certificate%20Authority%202018.crt' \
'http://www.microsoft.com/pkiops/certs/Microsoft%20Update%20Secure%20Server%20CA%201.crt' \
'https://www.microsoft.com/pkiops/certs/Microsoft%20Update%20Secure%20Server%20CA%202.1.crt' \
'https://www.microsoft.com/pkiops/certs/Microsoft%20Update%20Secure%20Server%20CA%202.2.crt' \
'http://www.microsoft.com/pkiops/certs/Microsoft%20ECC%20Content%20Distribution%20Secure%20Server%20CA%202.1.crt' \
'https://www.microsoft.com/pkiops/certs/Microsoft%20ECC%20Update%20Secure%20Server%20CA%202.1.crt' \
'https://www.microsoft.com/pkiops/certs/Microsoft%20ECC%20Update%20Secure%20Server%20CA%202.2.crt')
 
mkdir -p /opt/catchpoint/etc

# check to see if the directory exists and if no, create it
if [ ! -d $SUPPDIR ]; then
	mkdir $SUPPDIR
fi

# change directory
cd $SUPPDIR

# walk the array
for url in "${SUPPCA[@]}"
do
	echo "Pulling down - ${url}"
	cerFile="${url##*\/}"
	curl ${url} -o ${cerFile} --silent
	# update the OS level CA bundle home
	sudo cp ${SUPPDIR}/${cerFile} $ANCHORDIR
	sudo chcon -u system_u -t cert_t ${ANCHORDIR}/${cerFile}
done

# now some CP specific fun begins
# bulk convert the certificates into PEM format
for f in `ls -1 | awk -F.crt '{print $1}' | awk -F.cer '{print $1}'`
do
if [[ "${f}" == "Mic"* ]]
then
        openssl x509 -inform der -in ${f}.crt -out ${f}.pem
else
        openssl x509 -inform der -in ${f}.cer -out ${f}.pem
fi
done
# build the combined file
cat *.pem > /tmp/suppCA.pem
# save a backup and append the combined group to the bottom of the existing ca bundle
sudo cp ${CPSUPPDIR}/ca-bundle.crt ${CPSUPPDIR}/ca-bundle.crt.oem
sudo mv /tmp/suppCA.pem >> ${CPSUPPDIR}/ca-bundle.crt

# update the system level bundle
sudo update-ca-trust
sudo update-ca-trust enable

# update the CP bundles
sudo cert-sync /opt/catchpoint/etc/ca-bundle.crt

# To verify if Apple, Cisco & Microsoft certs are installed
# awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-bundle.crt | grep 'Microsoft\|Apple\|Cisco'

