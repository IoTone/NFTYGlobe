# NFTYGlobe
An NFC-based NFT Viewer for Opensea.io : A hardware + software project

## Building

There are external dependencies that need to be snarfed from the external 
filament repository here:

- https://github.com/google/filament/tree/v1.12.11
- The recommendation is to build the repository per instruction: 
https://github.com/google/filament/tree/v1.12.11/ios/samples#prequisites
- Once the filament build is done copy the output build into the external directory

mkdir -p filamentlib-1.12.1
cp -r YOURSOURCEDIRPATH/filament-1.12.11/out/ios-debug filamentlib-1.12.11 

## Demo Tag Setup

You need some NFC tags.  A standard NFC tag that has between 80-128bytes of memory 
should work fine.  Some of these contract addresses are long.  Some are not.

TODO: Add details on the tag setup

## Demo Viewer Setup

Setting up a viewer is optional.  The tags can be viewed directly on the phone.
To make a more interesting viewer, use a projector.  

TODO: Add the details on the setup and assembly of a design.
