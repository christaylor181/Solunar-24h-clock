# Solunar-24h-clock
A 24-hour clock on your iPhone that graphically shows the Sun and Moon rise/set times. Times derived from the United States Naval Observatory public Astronomical Applications web service. Choose your own typeface for the UI- I'm not able to include my cool Eurostile commercial font.

https://aa.usno.navy.mil/data/docs/api.php#rstt

There's a blue sector that gives an idea when the sun is above the horizon, as well as an arc sort of thing that shows when the moon is up for the local observer. Location services have to be ON for the app to know where you are.

Works on my iPhone 6 and 7. The US Navy recently did something with their SSL cert- I had to import the site's cert into Keychain on my Mac and add it to the key profile on my phone. I had to find a DoD Root CA 3 cert online and import it. The one I found was in an archive named Certificates_PKCS7_V5.4_DoD. This looks like it might be an updated one:

http://iasecontent.disa.mil/pki-pke/Certificates_PKCS7_v5.5_DoD.zip

## DISCLAIMER!
This is for experimentation only- do not use for any critical purpose! The author disclaims any warranty or liability for its use.
