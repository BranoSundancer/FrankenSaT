FrankenSaT
==========
[<img src="FrankenSaT_thumb.jpg" align="right"/>](FrankenSaT.jpg)

FrankenSaT is abbreviation of <b>"Frankenstein" Satellite Tracker</b> - an affordable DIY antenna rotator with Azimuth (pan) and optional Elevation (tilt) controlled by [Hamlib](https://github.com/Hamlib/Hamlib)'s _rotctld_ protocol. Why "Frankenstein"? Like the [creature of the same name](https://en.wikipedia.org/wiki/Frankenstein%27s_monster) in a [literary novel](https://en.wikipedia.org/wiki/Frankenstein), this project is ultimately ugly - both software and construction part.

# Advantages

* **Price**: It can be made by anyone who has an old satellite receiver with [OpenATV Enigma2](https://github.com/openatv/enigma2) in a drawer perhaps and a [DiSEqC](https://en.wikipedia.org/wiki/DiSEqC) motor for a satellite dish alignment. If not, both can be found on sale at a lower total price than many other antenna pan/tilt solutions. Other parts are just common hardware store items, often already owned in shed/garage.
* **Low skill requirement**: No need to solder, all electronics is already assembled in receiver. All you have to do is upload a Bash script to the receiver and you will get Azimuth motor control. The same script can also control second motor for Elevation.
* Carrying capacity: usually at least 10 kg per motor. When using two motors, there are still several kg available for the antenna.
* Weather proof motors by design.
* Optimal for "cliff" mount: angular span 150-180° of many motors seems to be enough for Azimuth rotation in such situations (like balcony). However, it is also possible to dynamically adjust the observation per every overflight: the center of the Azimuth motor position should point to Azimuth with maximum Elevation and the same value should be set to FrankenSaT, which recalculates the right Azimuth for that specific observation.

# Limitations

* Total weight and dimensions: approx. 3 kg per motor + antenna + stand.
* Satellite rotor shaft is (usually?) not straight but angled (35°, but maybe also other angles) - this must be compensated/tolerated while engineering construction.
* Some motors are not fast enough to track objects in higher Elevation, however those could be still usable for Elevation control.
* Some motors have too narrow angular span (like 90° instead of 160°), however those are still usable for Elevation control.

# Tested receivers

* Amiko Viper Combo (openATV 7.3)
* _coming soon..._

# Credits for support

* [Ahmed Al Hafoudh](https://www.linkedin.com/in/alhafoudh) - GitHub support and robots construction
* Jaroslav Stanko OM1AJS - SAT/DeSIqC devices support
* [Ondrej Farkas]( https://www.linkedin.com/in/ondrej-farkas-919b8519) OM2OFA - small satellites orbital construction and operation
* [OM3KFF](https://om3kff.sk/) ham club members - satellites observation support
