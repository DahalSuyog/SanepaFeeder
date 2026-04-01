# SanepaFeeder
## Update 31 March (Neshan)

STATCOM model for singular grid and singular load is completed.
Reactive power is supplied by inverter but the grid also provides enough for the load.
Source current is very high.
![alt text](<Screenshot 2026-03-31 at 8.08.50 pm.png>)
But the voltage maintains constant value.
![alt text](image-1.png)
Probably need to fix PID.
Also reference voltage for the inverter is also fluctuating and failing to maintain the value of 800V.
![alt text](image.png) maintaineance of around 50 V is seen.

May have been problem on inverter and PLL as well.
Trying to design new singular grid with diffrent inverter, controller and PLL.

## Conference Details
![Conference Info](member/subash/Picture/Conference_imp_date.png)