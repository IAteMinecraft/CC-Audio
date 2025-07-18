# CC Audio Player
---

This Repository contains an audio player, made entirely by me, and some audio files!

---

To actually use this audio player, you need to connect two computers together with a wired modem,  
then connect a few speakers (I find max 4 speakers works well)  
> &nbsp;&nbsp;&nbsp;&nbsp;NOTE: Do NOT put the speakers on the same network that connects the clients to the main computer,  
>&nbsp;&nbsp;&nbsp;&nbsp;it will cause the clients to fight for the speaker,  
>&nbsp;&nbsp;&nbsp;&nbsp;*bad* idea  

Put the two files from `programs/startup` onto the client computer, then reboot  
>&nbsp;&nbsp;&nbsp;&nbsp;The client script contains an auto-updater,  
>&nbsp;&nbsp;&nbsp;&nbsp;so you do not need to worry about having to update all the different clients connected to the network!

The main interface is rather simple to use, just click on an audio file on the right, and then hit the play button  
I highly recomend that you don't hit play until the "Found X clients" has been printed to the main Text area.

> NOTE: The main Interface reboots all the computers on the network, so that the clients will always be on and ready!

---

To install the main and client programs you can use:
> wget run https://github.com/IAteMinecraft/CC-Audio/raw/refs/heads/main/programs/installer <main|client>

where <main|client> represents which version you want to install, if no argument is provided, it defaults to main.

>The Client automatically runs on startup
>
>Run the main client with `main`

---

TODO:
- Allow using local files
- Allow using Youtube links
    - Add storing of added links