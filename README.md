# FrankenSaT

FrankenSaT is an abbreviation of <b>"Frankenstein" Satellite Tracker</b> - an affordable DIY antenna rotator with Azimuth (pan) and optional Elevation (tilt) controlled by PC or smartphone. Why "Frankenstein"? Like the [creature of the same name](https://en.wikipedia.org/wiki/Frankenstein%27s_monster) in a [literary novel](https://en.wikipedia.org/wiki/Frankenstein), this project is ultimately ugly - both software and construction part.

https://github.com/BranoSundancer/FrankenSaT/assets/127756743/9ce1be92-3cc4-41bd-9ff8-c4fe67d2202f

## TL;DR: How it works?

One or a pair "standard" Linux TV SAT receivers (with **openATV**) are used without any HW/SW modification and joined to a network. A single Bash script is uploaded and installed as a service to one of them. In the **openATV Linux UI**, the motor can be positioned at a specific angle. Additionally, **openATV provides a virtual remote control (HTTP API)**. The SW part **navigates through the menu** during initialization and **sets the motor's angle** accordingly, as requested by **commands received from rotctl client** (external satellite tracking software). If an elevation device is available in addition to azimuth control, the script operates both receivers simultaneously. This approach was chosen due to the lack of documentation on the driver and the time required for reverse engineering. **Unorthodox, but it works.**

## Advantages

[<img src="https://raw.githubusercontent.com/BranoSundancer/FrankenSaT/main/FrankenSaT.jpg" alt="FrankenSaT" title="FrankenSaT" width="150" align="right"/>](FrankenSaT.jpg)
* **Price and availability**: It can be made by anyone who has an old satellite receiver with [OpenATV Enigma2](https://github.com/openatv/enigma2) in a drawer and perhaps a [DiSEqC](https://en.wikipedia.org/wiki/DiSEqC) motor for a satellite dish alignment. If not, both can be found on sale at a total price lower than many other antenna pan/tilt solutions. Other parts are just common hardware store items, often already owned in shed/garage.
* **Compatibility**: Native [Hamlib](https://github.com/Hamlib/Hamlib)'s _rotctl_ protocol support used by satellite tracking software like [Gpredict](https://oz9aec.dk/gpredict/) and as a bonus, rotator control of the [Satellite Tracker (SatTrack)](https://apps.apple.com/us/app/satellite-tracker/id1438679383) app for iPhone/iPad by [Craig Vosburgh](https://www.linkedin.com/in/craigvosburgh) W0VOS.
* **Low skill requirement**: No need to solder, all electronics is already assembled in the receiver. You just is upload a Bash script to the receiver and you will get Azimuth motor control. The same script can also control second motor for Elevation.
* **Carrying capacity**: Usually at least 10 kg per motor. When using two motors (one carries the second one), there are still several kg available for the antenna.
* **Weather proof**: Motors are designed to outdoor mount. However, their position requires some additional protection of connectors.
* **Optimal for cliff mount**: Angular span 150-160° (let's call it "wide") of many motors seems to be enough for Azimuth rotation in such situations (like balcony). However, it is also possible to dynamically adjust the observation per every overflight (let's call it one-pass usage): the center of the Azimuth motor position should point to Azimuth with maximum Elevation and the same value should be set to FrankenSaT, which recalculates the right Azimuth for that specific observation. Since the direction of the installation changes for every pass in the sequence of observations, the running configuration of the Azimuth center is adjustable using web GUI.
* **Nearly 360° Azimuth possible**: If two motors with wide angular span are used (like 160°) and the Elevation motor's center is in perpendicular to the ground, averted Azimuth angles above 180° are reachable by overturning of the Elevation above 90°. The code is prepared for this operation and flips the Azimuth position to achieve the right vector. As a result, any pass is trackable. Azimuth/Elevation angles which are not reachable by limitation of the motors are tracked by (hopefully) the nearest possible angle.
* **No damage**: No irreversible modification of devices is needed. When you don't need the rotator anymore, you can use the receiver(s) and motor(s) for TV again.

## Limitations

[<img src="https://raw.githubusercontent.com/BranoSundancer/FrankenSaT/main/motors.jpg" alt="Azimuth and Elevation motors connected together" title="Azimuth and Elevation motors connected together" width="150" align="right"/>](motors.jpg)
* Total weight and dimensions: approx. 3 kg per motor + antenna + stand totals the weight over 10 kg, which in combination with dimensions limits portability options.
* Satellite rotor shaft is usually not straight but angled (35°, 45°, most likely other angles too) - this must be compensated/tolerated while construction engineering.
* Some motors are not fast enough to track Azimuth of objects in higher Elevation, however those could be still usable for Elevation control.
* Some motors have too narrow angular span (like 90° instead of 160°), however those are still usable for Elevation control for cliff/one-pass usage.

## Tested receivers

* Amiko Viper Combo (openATV 7.3)
* Show Box Vitamin HD 5000 256MB Enigma 2 PRO (openATV 5.1 / EAGLE)

## Transceiver control

Doppler frequency shift is  another significant aspcet of the objective. It is possible to automate it also with Gpredict, you just need a rig which is controllable using Hamlib's rigctld. If you don't have one, you could try (really cheap) Quansheng UV-K5 with [quansheng-dock-fw](https://github.com/nicsure/quansheng-dock-fw) and Windows desktop software [Quansheng Dock (mod/om1atb)](https://github.com/BranoSundancer/QuanshengDock-mod-om1atb/releases) which allows that.

## The Story Behind the Project

### Motivation

I started listening to **phonetic amateur radio traffic on satellite repeaters**. Naturally, I wanted to try making a connection myself, but it was quite challenging: antenna tracking of a moving satellite, constant retuning of two frequencies (TX & RX) due to the Doppler effect, finding an opportunity to transmit on busy satellites, listening for responses, correctly capturing the call sign, completing the QSO (mutual confirmation).

I just couldn’t manage it all together. My family helped turn the antenna for about a week, but their enthusiasm faded quickly. So, I figured an **automatic antenna rotator and automatic frequency tuning** would be the solution. There is software for both, and with a good transceiver, it’s just a matter of connecting the right components (I didn’t have one, so I contributed to a project for a cheaper one I own, and now it works). **Only the rotator was missing.**

### Efficient Solution

I first checked how others solved this problem. They either **bought a rotator** for **€500-€1500** (too big of an investment for a single experiment) or **built their own**, which seemed time-consuming. Then I noticed that some people use **DISEqC motors from TV SAT antennas**. These have limitations, but with custom electronics, they work. However, even that seemed like too much effort.

Then I realized: **TV SAT receivers already have control electronics and a driver for these motors**. Yet, no one had tried using them for this purpose. So, I bought a Linux-based receiver second-hand, received a motor as a gift from a friend, and started experimenting.

### Proof of Concept

I had no idea what to expect, having never worked with such devices. Using a remote control, I moved the motor as if pointing at a stationary satellite, but that wasn’t enough—I needed **precise step-by-step rotation on demand**. In the **openATV UI**, I found an option for this.

I attempted to bypass the UI to send commands directly to the driver, but despite studying the available source code, I couldn’t find the right method. Then I realized: **Why bother? openATV has a web interface with a virtual remote control!**

To rotate the motor step by step, I only needed to navigate to the correct menu and adjust the angle. I captured the necessary HTTP commands from the virtual remote and immediately gained **full programmatic control** over the menu—and thus the motor—via Bash scripting.

### Development

From there, things progressed quickly. I studied the **rotctl protocol**, implemented a a Bash version, and linked it to a **satellite tracking program**.

Next, I added an elevation control system (another set of receiver and motor) alongside the azimuth motor and mounted both at the correct angles (which was a bit tricky due the SAT axles angles). Only **one receiver executes the script**, navigating through the menu and controlling both motors.

### Result

The script evolved to include:

- A **simple web-based GUI (server part written in Bash too)** for calibration (which works as a **virtual iPhone app**)
- Full **rotctld command compatibility**
- **Configuration options** for setups with or without elevation, motor assembly details, and physical operational ranges
- **Persistent settings across reboots**
- **WiFi connectivity** and its own network (2 receivers + router)

There’s still room for improvement, but for its **primary purpose, it works perfectly**—just **plug it in and go**.

## Credits

* [Ahmed Al Hafoudh](https://www.linkedin.com/in/alhafoudh) - GitHub and robots engineering support
* [Ondrej Farkas](https://www.linkedin.com/in/ondrej-farkas-919b8519) OM2FON - small satellites engineering and orbital operation support
* Jaroslav Stanko OM1AJS - SAT/DiSEqC devices support
* [OM3KFF](https://om3kff.sk/) ham club members - satellites observation and communication support
* [Craig Vosburgh](https://www.linkedin.com/in/craigvosburgh) W0VOS - SatTrack app API specification
* [Icons8](https://icons8.com/) - favicon

[![Per Aspera Ad Astra](https://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/Per_aspera_ad_astra%2C_1894.jpg/640px-Per_aspera_ad_astra%2C_1894.jpg)](https://simple.wikipedia.org/wiki/Per_aspera_ad_astra)
