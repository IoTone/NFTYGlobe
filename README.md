# NFTYGlobe
An NFC-based NFT Viewer for Opensea.io : A hardware + software project

Demo: https://1drv.ms/v/s!AuIL2jCvMCqRgp5Y2U7wrm_aMuciMQ?e=sRZJJm
also: https://1drv.ms/v/s!AuIL2jCvMCqRgp5XjitcwdyHgB-d3g?e=6jeBTw

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

- The viewer is built from a light bulb head (a FEIT bulb of some kind, pop off the plastic dome part; TODO add the model))
- A cardboard tube used for shipping (TODO: get the dimensions and diameter)
- The projector: a polaroid mini HDMI projector that is sub $200 on amazon
- NFC tags: I buy mine from tagstand.com (TODO: write up specs for configuring NFC tags)
