#Check admin rights
if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi


MAIN_SRV_DIST=TBD
MAIN_SRV_REPO=TBD
MAIN_SRV_DOMAIN=TBD
JibriBrewery=TBD
JB_NAME=TBD
JB_AUTH_PASS=TBD
JB_REC_PASS=TBD
MJS_USER=TBD
MJS_USER_PASS=TBD
JIBRI_RES_CONF=TBD
JIBRI_RES_XORG_CONF=TBD
SHORT_ID=$(wget -q -O - "http://169.254.169.254/latest/meta-data/instance-id")
NICKNAME=`uuidgen`


echo -e "Updating hostname..."
hostnamectl set-hostname "jbnode_${SHORT_ID}.${MAIN_SRV_DOMAIN}"
sed -i "1i 127.0.0.1 jbnode_${SHORT_ID}.${MAIN_SRV_DOMAIN}" /etc/hosts


echo -e "Updating Jibri Settings..."

## New Jibri Config (2020)
cat << NEW_CONF > "$JIBRI_CONF"
// New XMPP environment config.
jibri {
    streaming {
        // A list of regex patterns for allowed RTMP URLs.  The RTMP URL used
        // when starting a stream must match at least one of the patterns in
        // this list.
        rtmp-allow-list = [
          // By default, all services are allowed
          ".*"
        ]
    }
    ffmpeg {
        resolution = "$JIBRI_RES_CONF"
    }
    chrome {
        // The flags which will be passed to chromium when launching
        flags = [
          "--use-fake-ui-for-media-stream",
          "--start-maximized",
          "--kiosk",
          "--enabled",
          "--disable-infobars",
          "--autoplay-policy=no-user-gesture-required",
          "--ignore-certificate-errors",
          "--disable-dev-shm-usage"
        ]
    }
    stats {
        enable-stats-d = true
    }
    call-status-checks {
        // If all clients have their audio and video muted and if Jibri does not
        // detect any data stream (audio or video) comming in, it will stop
        // recording after NO_MEDIA_TIMEOUT expires.
        no-media-timeout = 30 seconds

        // If all clients have their audio and video muted, Jibri consideres this
        // as an empty call and stops the recording after ALL_MUTED_TIMEOUT expires.
        all-muted-timeout = 10 minutes

        // When detecting if a call is empty, Jibri takes into consideration for how
        // long the call has been empty already. If it has been empty for more than
        // DEFAULT_CALL_EMPTY_TIMEOUT, it will consider it empty and stop the recording.
        default-call-empty-timeout = 30 seconds
    }
    recording {
         recordings-directory = $DIR_RECORD
         finalize-script = $REC_DIR
    }
    api {
        xmpp {
            environments = [
                {
                // A user-friendly name for this environment
                name = "$JB_NAME"

                // A list of XMPP server hosts to which we'll connect
                xmpp-server-hosts = [ "$MAIN_SRV_DOMAIN" ]

                // The base XMPP domain
                xmpp-domain = "$MAIN_SRV_DOMAIN"

                // The MUC we'll join to announce our presence for
                // recording and streaming services
                control-muc {
                    domain = "internal.auth.$MAIN_SRV_DOMAIN"
                    room-name = "$JibriBrewery"
                    nickname = "machine-id"
                }

                // The login information for the control MUC
                control-login {
                    domain = "auth.$MAIN_SRV_DOMAIN"
                    username = "jibri"
                    password = "$JB_AUTH_PASS"
                }

                // An (optional) MUC configuration where we'll
                // join to announce SIP gateway services
            //    sip-control-muc {
            //        domain = "domain"
            //        room-name = "room-name"
            //        nickname = "nickname"
            //    }

                // The login information the selenium web client will use
                call-login {
                    domain = "recorder.$MAIN_SRV_DOMAIN"
                    username = "recorder"
                    password = "$JB_REC_PASS"
                }

                // The value we'll strip from the room JID domain to derive
                // the call URL
                strip-from-room-domain = "conference."

                // How long Jibri sessions will be allowed to last before
                // they are stopped.  A value of 0 allows them to go on
                // indefinitely
                usage-timeout = 0 hour

                // Whether or not we'll automatically trust any cert on
                // this XMPP domain
                trust-all-xmpp-certs = true
                }
            ]
        }
    }
}
NEW_CONF

echo -e "Jibri config file updated!"

echo -e "Replacing Jibri Instance Nickname..."
sudo sed -i "s/nickname = [^ ]*/nickname = \"$NICKNAME\"/g" /etc/jitsi/jibri/jibri.conf

echo -e "Done!"
echo -e "Restarting Jibri service..."

systemctl restart jibri
systemctl restart jibri-xorg
systemctl restart jibri-icewm