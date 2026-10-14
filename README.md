# NotProton

NotProton enables the Steam Play experience from Linux Steam in the macOS Steam client.

This is done by forcibly enabling the Steam Play functionality in macOS Steam (which is
present and inert) as well as by porting some components of Valve's Proton to macOS.

This tool is intended to be used with Steam Client 1788652215 or 1790121765 and **CrossOver 26.3 or CrossOver Preview
20261006 or 2026082**. Both the FEX and the Rosetta versions are supported. I recommend using the FEX version of the 
Preview 20261006, as it includes both the FEX version as well as the Rosetta one. 

I recommend going into Steam Settings - Compatibility and selecting the Rosetta version as your default compatibility tool, selecting FEX on a per game basis by right clicking a game in Steam, going into Properties - Compatibility and selecting FEX there.

**This project now has a brew cask.** For brew users, you can install via ``brew install --cask notprotonnot/notproton/notproton``

As far as the source structure goes, the macOS app itself is located in the ```app``` folder. The core logic is in ```dylib```.
```lsteamclient``` is a macOS port of Valve's lsteamclient. ```steam-shim```is a port of Valve's
steam-helper from Proton 9. ntdll-patch patches the copy of CrossOver that the app
makes/places in the ```~/Library/Application Support/notproton/runners/``` folder so that
lsteamclient is loaded.

Written documentation is quite sparse, I intend to write more today. Please read NOTICE for license information.

Please open issue reports with any issues. PRs are welcome and encouraged. Contributions policy to come shortly.

There are many people who worked on similar ideas, similar projects. I did not base NotProton on their work, but I still want to 
give thanks to the people who came before me:

[Nat Brown](https://github.com/natbro) made [Kaon](https://github.com/natbro/kaon), which is similar in goals to NotProton.

mont127's [Neutron](https://github.com/mont127/Neutron) is also a similar idea, but implemented differently. 

[Gio](https://github.com/giodotblue) was working enabling Steam Play inside of Steam on macOS prior to the release of NotProton itself. 
I would have done things differently had I been aware of that. 

Thanks to everyone who has positively contributed to macOS gaming. 
