# FrankenSaT

FrankenSaT is an abbreviation of <b>"Frankenstein" Satellite Tracker</b> - an affordable DIY antenna rotator with Azimuth (pan) and optional Elevation (tilt) controlled by PC or smartphone. Why "Frankenstein"? Like the [creature of the same name](https://en.wikipedia.org/wiki/Frankenstein%27s_monster) in a [literary novel](https://en.wikipedia.org/wiki/Frankenstein), this project is ultimately ugly - both software and construction part.

https://github.com/BranoSundancer/FrankenSaT/assets/127756743/9ce1be92-3cc4-41bd-9ff8-c4fe67d2202f

## Advantages

[<img src="https://raw.githubusercontent.com/BranoSundancer/FrankenSaT/main/FrankenSaT.jpg" alt="FrankenSaT" title="FrankenSaT" width="150" align="right"/>](FrankenSaT.jpg)
* **Price and availability**: It can be made by anyone who has an old satellite receiver with [OpenATV Enigma2](https://github.com/openatv/enigma2) in a drawer and perhaps a [DiSEqC](https://en.wikipedia.org/wiki/DiSEqC) motor for a satellite dish alignment. If not, both can be found on sale at a total price lower than many other antenna pan/tilt solutions. Other parts are just common hardware store items, often already owned in shed/garage.
* **Compatibility**: Native [Hamlib](https://github.com/Hamlib/Hamlib)'s _rotctld_ protocol support used by satellite tracking software like [Gpredict](https://oz9aec.dk/gpredict/) and as a bonus, rotator control of the [Satellite Tracker (SatTrack)](https://apps.apple.com/us/app/satellite-tracker/id1438679383) app for iPhone/iPad by [Craig Vosburgh](https://www.linkedin.com/in/craigvosburgh) W0VOS.
* **Low skill requirement**: No need to solder, all electronics is already assembled in the receiver. You just is upload a Bash script to the receiver and you will get Azimuth motor control. The same script can also control second motor for Elevation.
* **Carrying capacity**: Usually at least 10 kg per motor. When using two motors (one carries the second one), there are still several kg available for the antenna.
* **Weather proof**: Motors are designed to outdoor mount. However, their position requires some additional protection of connectors.
* **Optimal for cliff mount**: Angular span 150-160° (let's call it "wide") of many motors seems to be enough for Azimuth rotation in such situations (like balcony). However, it is also possible to dynamically adjust the observation per every overflight (let's call it one-pass usage): the center of the Azimuth motor position should point to Azimuth with maximum Elevation and the same value should be set to FrankenSaT, which recalculates the right Azimuth for that specific observation. Since the direction of the installation changes for every pass in the sequence of observations, the running configuration of the Azimuth center is adjustable using web GUI.
* **Nearly 360° Azimuth possible**: If two motors with wide angular span are used (like 160°) and the Elevation motor's center is in perpendicular to the ground, averted Azimuth angles above 180° are reachable by overturning of the Elevation above 90°. The code is prepared for this operation and flips the Azimuth position to achieve the right vector. As a result, any pass is trackable. Azimuth/Elevation angles which are not reachable by limitation of the motors are tracked by (hopefully) the nearest possible angle.
* **No damage**: No irreversible modification of devices is needed. When you don't need the rotator anymore, you can use the receiver(s) and motor(s) for TV again.

## Limitations

[<img src="https://raw.githubusercontent.com/BranoSundancer/FrankenSaT/main/motors.jpg" alt="Azimuth and Elevation motors connected together" title="Azimuth and Elevation motors connected together" width="150" align="right"/>](motors.jpg)
* Total weight and dimensions: approx. 3 kg per motor + antenna + stand.
* Satellite rotor shaft is usually not straight but angled (35°, 45°, most likely other angles too) - this must be compensated/tolerated while construction engineering.
* Some motors are not fast enough to track Azimuth of objects in higher Elevation, however those could be still usable for Elevation control for cliff/one-pass usage.
* Some motors have too narrow angular span (like 90° instead of 160°), however those are still usable for Elevation control for cliff/one-pass usage.

## Tested receivers

* Amiko Viper Combo (openATV 7.3)
* Show Box Vitamin HD 5000 256MB Enigma 2 PRO (openATV 5.1 / EAGLE)

## Credits

* [Ahmed Al Hafoudh](https://www.linkedin.com/in/alhafoudh) - GitHub and robots engineering support
* [Ondrej Farkas](https://www.linkedin.com/in/ondrej-farkas-919b8519) OM2FON - small satellites engineering and orbital operation support
* Jaroslav Stanko OM1AJS - SAT/DiSEqC devices support
* [OM3KFF](https://om3kff.sk/) ham club members - satellites observation and communication support
* [Icons8](https://icons8.com/) - favicon

[![Per Aspera Ad Astra](https://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/Per_aspera_ad_astra%2C_1894.jpg/640px-Per_aspera_ad_astra%2C_1894.jpg)](https://simple.wikipedia.org/wiki/Per_aspera_ad_astra)
