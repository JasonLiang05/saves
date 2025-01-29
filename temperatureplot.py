import sys, time, serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import matplotlib.ticker as ticker

# configure the serial port
ser = serial.Serial(
    port='COM3',             
    baudrate=115200,        
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1
)
ser.isOpen()

# read 4 byte a time
def data_gen():
    start_time = time.time()
    while True:
        #read 4 bytes from serial
        raw_bytes = ser.read(4)
        if len(raw_bytes) < 4:
            #continue to next loop
            continue

        # convert the read value into integers
        val_32 = int.from_bytes(raw_bytes, byteorder='little', signed=True)
        # since in n76e003, the raw value is dC instead of C, devide by 100(float) to convert it into float tmperature value
        temp_c = val_32 / 100.0
        # The current time is value of x in sec 
        curr_time = time.time() - start_time
        yield curr_time, temp_c
        # print temperature to terminal
        print(f"Current Temperature: {temp_c:+7.2f} °C")

#Graph function
def run(data):
    t, y = data
    xdata.append(t)
    ydata.append(y)

    #30 secs length time domain
    if t > 30:
        ax.set_xlim(t - 30, t)

    line.set_data(xdata, ydata)
    return line, 

def on_close_figure(event):
    sys.exit(0)

#Graph settings
fig, ax = plt.subplots(figsize=(8, 6))
fig.subplots_adjust(left=0.05,right=0.98,top=0.96,bottom=0.07)#graph shape
fig.canvas.mpl_connect('close_event', on_close_figure)
line, = ax.plot([], [], lw=2)
ax.yaxis.set_major_locator(ticker.MultipleLocator(5))#grid line modification
ax.set_ylim(-40, 110)               #y, temperatire range
ax.set_xlim(0, 30)                 #x, initial sec domain
ax.set_xlabel("Time (s)")
ax.set_ylabel("Temperature (°C)")
ax.set_title("Temperature-Time Data graph")
ax.xaxis.set_major_locator(ticker.MultipleLocator(1)) #grid line modification
ax.tick_params(axis='x', labelsize=8) #Smaller size of numbers in x(sec), so no overllape
ax.grid(which='major', axis='both')

xdata, ydata = [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()
