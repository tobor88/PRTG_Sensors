# PRTG_Sensors
Sensors for the PRTG Network Monitoring Application

### ResourceMonitor.ps1
I created this sensor to condense the output of RAM, Disk Usage, and CPU Load into one sensor for easy viewing and for getting the most out of the PRTG Network Monitoring Tool. The XML needs to be exact if you are going to make ay changes. PRTG  translates integers once they are received. Sometimes you need to multiply or divied by 1MB or 1GB to get the correct format. Best to use this sensor as is.

There are a few fields that are commented out that can easily be added to the PRTG final sensor by just copying them from the comments inside the $XML variable between <Result> tags. I left outthe below fields.
  - TotalDisks
  - TotalCPUs
  - Memory Bytes In Use
  - Memory Bytes Free
  
  Fields included in the sensor are listed below.
  - CPU # Load
  - Memory Free Percentage
  - Memory In Use Percentage
  - Total Memory
  - Total Space Drive ?:\
  - Percentage Free on Drive ?:\

Warning and Error triggers are set on the following.
- Percentage Freem on Drive ?:\  below WARN: 15% and ERROR: 10%
- Memory In Use Percentage above WARN: 85% and ERROR: 95%
- CPU Loads above WARN: 85% and ERROR: 95% 

An image of the output can be seen below.
![Image of PRTG Results in GUI](https://raw.githubusercontent.com/tobor88/PRTG_Sensors/master/PRTG_Result_Image.png)

### Configuration of Sensor
An image of the configuration can be listed below. It is crucial that the following requirements are met for this sensor to work.
-  Device Name needs to be set to hostname.domain.com. This defines what machines is being communicated with.
- Configure the parent level of the devices you are adding this sensor to. We want them to use Windows Authentication with an account that can access LDAP and issue remote commands. 
- Parameter needs to mirror the following text exactly in order to fill in the device variable parameter: '%device' 
- Ensure use Windows Credentials of parents device is selected and configured with the account I mentioned above.
- If this will run on a bunch of machines it is best to create a mutext record. This allows more than one instance of the script to run. It is easier than making more files with a slightly different name.

I am pretty sure I covered everything. Hope someone benefits from this as it was time consuming.

![Image of PRTG Sensor Settings](https://raw.githubusercontent.com/tobor88/PRTG_Sensors/master/PRTG_Sensor_Image.png)
