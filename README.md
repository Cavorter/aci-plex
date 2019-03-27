# Plex Media Server deployment to Azure Container Instance

I've been running my own Plex server off and on for a number of years and recently have decided to try moving it off site for a number of reasons. This repo is mostly for keeping track of the experiment and should NOT be considered a gold standard for deployment or management of your own server, but feel free to fork at your own risk.

## Why Azure?

Basically I'm a Windows guy and am paid pretty well to write PowerShell all day so it's a pretty easy draw for me. Plus this lets me try out some things that we aren't quite using at work yet which might be useful to me later.

## Dev Log

### v1 - Single ARM Template
The first iteration of this had a single `template.json` file that had the storage account, plex container, and also a seperate container just to setup the media share. Why the seperate container? Because ARM templates (when I am writing this) don't support Azure Files shares just yet so they recomend spinning up an AZ CLI container and running a command in it. [I'm not kidding.](https://github.com/Azure/azure-quickstart-templates/tree/master/101-aci-storage-file-share) But that is going to be a PITA since I also want to generate a configuration share so it doesn't have to rebuild the library every time the container restarts.

### v2 - Terraform!
The second iteration of this was going really well since Terraform _*DOES*_ support Azure Files shares natively! The downside is that unlike ARM Templates it does _*NOT*_ support empty volume mounts for the transcoding, but at least that volume is optional. So I get it spun up and the container at least is running, but it never responds in the browser.

So I figure I'll have a look at the logs and I _should_ be able to read them by mounting up my config share and just reading the logs. VERY long story short: [Comcast (my internet provider) blocks port 445](https://stackoverflow.com/questions/48233157/cannot-connect-to-azure-file-share) which is necessary to be able to mount the share, so no dice there. OTOH there is a preview of a file browser available in the portal so I went spelunking and found the following:

```
Mar 26, 2019 21:16:41.815 [0x7fa84a7fe700] INFO - Plex Media Server v1.14.1.5488-cc260c476 - Docker Docker Container x86_64 - build: linux-ubuntu-x86_64 ubuntu - GMT -05:00
Mar 26, 2019 21:16:41.816 [0x7fa84a7fe700] INFO - Linux version: 4.15.0-1040-azure, language: C
Mar 26, 2019 21:16:41.816 [0x7fa84a7fe700] INFO - Processor Intel(R) Xeon(R) CPU E5-2673 v3 @ 2.40GHz
Mar 26, 2019 21:16:41.816 [0x7fa84a7fe700] INFO - /usr/lib/plexmediaserver/Plex Media Server
Mar 26, 2019 21:16:41.276 [0x7fa856669800] DEBUG - BPQ: [Idle] -> [Starting]
Mar 26, 2019 21:16:41.539 [0x7fa856669800] DEBUG - Opening 20 database sessions to library (com.plexapp.plugins.library), SQLite 3.13.0, threadsafe=1
Mar 26, 2019 21:16:43.231 [0x7fa8493ff700] DEBUG - Job running: '/usr/lib/plexmediaserver/CrashUploader' '--directory=/config/Library/Application Support/Plex Media Server/Crash Reports/1.14.1.5488-cc260c476' '--version=1.14.1.5488-cc260c476' '--platform=linux-ubuntu-x86_64 (4.15.0-1040-azure)' '--serverUuid=1234567890' '--userId=NOUSERID' '--url=https://crashreport.plexapp.com'
Mar 26, 2019 21:16:43.234 [0x7fa8493ff700] DEBUG - Jobs: Starting child process with pid 297
Mar 26, 2019 21:16:43.340 [0x7fa8483ff700] DEBUG - Jobs: '/usr/lib/plexmediaserver/CrashUploader' exit code for process 297 is 0 (success)
Mar 26, 2019 21:16:56.625 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:17:11.904 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:17:27.182 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:17:42.461 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:17:57.749 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:18:13.019 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:18:28.302 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:18:41.278 [0x7fa8473ff700] DEBUG - BPQ: [Starting] -> [Processing]
Mar 26, 2019 21:18:43.585 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:18:58.864 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:19:14.265 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
Mar 26, 2019 21:19:29.546 [0x7fa856669800] ERROR - SQLITE3:0x10, 5, statement aborts at 1: [PRAGMA journal_mode=WAL] database is locked
```

Apparently I had ignored some earlier warnings at my own peril: SQLite really doesn't like SMB, so no Config share for this instance which is going to make it hard to persist configuration across reboots since as previously noted the provider only has support for file share mounts. (Not even the _really_ cool [`gitrepo` mount type](https://docs.microsoft.com/en-us/azure/templates/microsoft.containerinstance/2018-10-01/containergroups#gitrepovolume-object)!)

### v3 - Next?