# MamboCoin
Shell script to install a [MamboCoin Masternode](http://mambocoin.com) on a Linux server running Ubuntu 16.04. Use it on your own risk.  

***
## Installation:  

wget https://raw.githubusercontent.com/oldskooltek/mambo_masternode/master/mambo_install.sh

sudo bash mambo_install.sh
***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the MamboCoin Desktop Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **30000** MAMBO to **MN1**.  
4. Wait for 20 confirmations.  
5. Go to **Help -> "Debug Windwow - Console"**  
6. Type the following command: **masternode outputs**  
7. Go to **MamboNodes** tab  
8. Click **Create** and fill the details:  
* Alias: **MN1**  
* Address: **VPS_IP:PORT**  
* Privkey: **Masternode Private Key**  
* TxHash: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
* Reward address: leave blank  
* Reward %: leave blank  
9. Click **OK** to add the masternode  
10. Click **Start All**  

***

## Usage:  



mambocoind masternode status

mambocoind getinfo

mambocoind getblockcount
```  
Also, if you want to check/start/stop **mambocoind** , run one of the following commands as **root**:
```
systemctl status mambocoind #To check the service is running  
systemctl start mambocoind #To start mambocoind service  
systemctl stop mambocoind #To stop cropcpoind service  
```

Donations
MamboCoin: mXmcp6KvqQK8VAnHXNd5j8kB62VoFVj2cS

  
