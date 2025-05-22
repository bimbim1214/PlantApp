import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _ctrl = Completer();
  Marker? _pickedMarker;
  String? _pickedAdress;
  String? _currentAdress;
  CameraPosition? _initialCamera;
  Position? _currentPosition;

  @override
  void initState(){
    super.initState();
    _setupLocation();
  }

  Future<void> _setupLocation() async {
    try {
      final pos = await getPermissions();
      _currentPosition = pos;
      _initialCamera = CameraPosition(
        target: LatLng(pos.latitude, pos.longitude),
        zoom: 16,
      );

      final placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final p = placemarks.first;
      _currentAdress = '${p.name}, ${p.locality}, ${p.country}';

      setState(() {});
    } catch (e) {

      _initialCamera = const CameraPosition(target: LatLng(0, 0), zoom: 2);
      setState(() {});
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<Position> getPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location service belum aktif';
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw 'Izin lokasi di tolak';
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak permanen';
    }

    return Geolocator.getCurrentPosition();
  }

  Future<void> _onTap(LatLng latlng) async {
    final placemarks = await placemarkFromCoordinates(
      latlng.latitude, 
      latlng.longitude,
    );

    final p = placemarks.first;
    setState(() {
      _pickedMarker = Marker(
        markerId: const MarkerId('picked'),
        position: latlng,
        infoWindow: InfoWindow(
          title: p.name?.isNotEmpty == true ? p.name : 'Lokasi Dipilih',
          snippet: '${p.street}, ${p.locality}',
        )
      );
    });
    final ctrl = await _ctrl.future;
    await ctrl.animateCamera(CameraUpdate.newLatLngZoom(latlng, 16));

    setState(() {
      _pickedAdress = 
          '${p.name},${p.street},${p.locality},${p.country},${p.postalCode}';
    });
  }

  void _confirmSelection() {
    showDialog(
      context: context, 
      builder: 
          (_) => AlertDialog(
            title: const Text('Konfirmasi Alamat'),
            content: Text(_pickedAdress ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, _pickedAdress);
                },
                child: const Text('Pilih')
              )
            ],
          )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialCamera == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Alamat')),
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialCamera!,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.satellite,
              compassEnabled: true,
              tiltGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              trafficEnabled: true,
              buildingsEnabled: true,
              indoorViewEnabled: true,
              onMapCreated: (GoogleMapController ctrl) {
                _ctrl.complete(ctrl);
              },

              markers: _pickedMarker != null ? {_pickedMarker!} : {},
              onTap: _onTap,
            ),
            Positioned(
              top: 250,
              left: 56,

              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(_currentAdress ?? 'Kosong'),
              ),
            ),
            if (_pickedAdress != null)
              Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _pickedAdress!,
                      style: const TextStyle(fontSize: 16),
                    ), 
                  ),
                )
              )
          ],
        )
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (_pickedAdress != null)
            FloatingActionButton.extended(
              onPressed: _confirmSelection,
              heroTag:  'confirm',
              label: const Text("Pilih Alamat"),
            ),

          const SizedBox(height: 8),
          if (_pickedAdress != null)
            FloatingActionButton.extended(
              heroTag: 'clear',
              label: const Text('Hapus Alamat'),
              onPressed: () {
                setState(() {
                  _pickedAdress = null;
                  _pickedMarker = null;
                });
              },
            )
        ],
      ),
    );
  }
}