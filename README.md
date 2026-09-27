# VoltSwap — Smart Battery Swapping Platform

VoltSwap is an **IoT-enabled smart battery swapping platform for electric vehicles**, developed using **Flutter, Supabase, ESP32, and Embedded C++**. The system integrates a mobile application, cloud backend, and ESP32-based hardware to enable real-time battery monitoring, station management, and automated battery swapping operations.

The project was **fully implemented and demonstrated using an ESP32-based prototype**, showcasing communication between the embedded hardware, cloud database, and mobile application.

## Project Overview

The system is designed to simplify EV battery swapping by allowing users to locate available swapping stations, view battery availability and charge levels, request a battery, and receive a QR code for the swap process.

The ESP32 acts as the embedded hardware controller and provides battery and slot information to the cloud backend. The Flutter application retrieves this information in real time and presents it to users and administrators.

### System Architecture

**ESP32 Hardware → Supabase Backend → Flutter Mobile Application**

* **ESP32:** Embedded controller for battery slot monitoring and hardware interaction.
* **Supabase:** Cloud backend for authentication, database management, and real-time data synchronization.
* **Flutter:** Cross-platform mobile application for users and administrators.
* **Google Maps:** Location-based visualization of battery swapping stations.

## Features Implemented

### User Features

* User registration and authentication using email and password.
* Vehicle number and Aadhaar number registration.
* Google Maps-based home screen.
* Real-time display of battery swapping stations.
* Current location visualization.
* Station markers with battery and slot information.
* Station details including available slots and battery charge levels.
* Automatic selection of the battery with the highest `charge_percentage`.
* Battery swap request functionality.
* QR code generation containing:

  * Station ID
  * Slot ID
  * Battery charge percentage
* Battery health and charge monitoring.
* Swap history tracking.
* Profile management.
* Vehicle number editing.
* Aadhaar number displayed as read-only.
* Secure sign-out functionality.

### Admin Features

* Separate administrator login.
* Add and manage battery swapping stations.
* Enable or disable station status.
* Manage battery slot availability.
* Monitor battery stock.
* View and manage station information.
* Advanced options for battery allocation.
* **Deallocate All Batteries** functionality with confirmation.
* Real-time management of battery and station data.

## ESP32 & IoT Integration

The project was implemented with an **ESP32-based embedded system** to demonstrate real-time communication between the physical battery-swapping hardware and the cloud backend.

The ESP32 was programmed using **C++** and integrated with the system to monitor and update battery slot parameters such as:

* `charge_percentage`
* `battery_present`
* Battery slot status
* Battery availability

The ESP32 communicates the hardware status to the backend, allowing the Flutter application to display updated battery information in real time.

The complete system was **tested and demonstrated using the ESP32 prototype**, validating the hardware–software integration and real-time data flow.

## Battery Selection Logic

When a user requests a battery swap, the system checks the available battery slots and selects the battery with the **highest charge percentage** among slots where:

```text
battery_present = true
```

The selected battery and slot information are then associated with the user's swap request.

## QR-Based Battery Swap

After a successful battery request, the application generates a QR code containing the relevant swap information:

```text
Station ID
Slot ID
Charge Percentage
```

This QR code can be used as part of the battery-swapping workflow at the station.

## Technology Stack

### Software

* **Flutter**
* **Dart**
* **Supabase**
* **PostgreSQL**
* **Google Maps API**

### Embedded / Hardware

* **ESP32**
* **Embedded C++**
* IoT communication
* Battery slot monitoring
* Real-time hardware data updates

### Project Concepts

* IoT
* Embedded Systems
* Mobile Application Development
* Cloud Database
* Real-Time Data Synchronization
* Hardware–Software Integration
* EV Battery Management
* QR-Based Authentication/Identification

## Project Structure

```text
VoltSwap/
│
├── lib/
│   ├── screens/
│   ├── models/
│   ├── services/
│   └── utils/
│
├── master_schema.sql
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

## Database Structure

The Supabase backend contains the following primary entities:

### Users

Stores user account and vehicle information.

```text
id
email
name
phone
vehicle_number
aadhar_number
current_battery_slot_id
current_station_id
assigned_battery_id
battery_status
created_at
updated_at
```

### Stations

Stores battery swapping station information.

```text
station_id
latitude
longitude
status
created_at
updated_at
```

### Slots

Stores individual battery slot and battery status information.

```text
id
slot_id
station_id
charge_percentage
battery_present
created_at
updated_at
```

### Swap Requests

Stores user battery swap requests and their status.

```text
id
user_id
station_id
slot_id
status
created_at
updated_at
```

## Security

Row Level Security (RLS) policies were implemented in Supabase to control database access.

* Users can view and update their own profile.
* Users can create and view their own swap requests.
* Authenticated users can read station and slot information.
* Administrative operations are restricted to authorized access.

## Real-Time Data Flow

The completed system follows this data flow:

```text
       ESP32
         │
         │ Battery / Slot Data
         ▼
   Supabase Backend
         │
         │ Real-Time Updates
         ▼
   Flutter Application
         │
         ├── User Interface
         ├── Station Map
         ├── Battery Status
         └── Swap Requests
```

This enables the application to reflect changes in battery availability and charge status without relying on static or dummy station data.

## Demonstration

The complete VoltSwap system was **implemented and successfully demonstrated using an ESP32-based hardware prototype**.

The demonstration showcased:

* ESP32-based battery slot monitoring
* Real-time battery status updates
* Cloud database synchronization
* Flutter mobile application integration
* Battery station visualization
* Battery availability and charge monitoring
* Battery swap request workflow
* QR code generation
* Admin station and battery management

## Setup

### 1. Install Flutter Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

Update:

```text
lib/utils/app_config.dart
```

with the required Supabase configuration.

### 3. Configure Google Maps

Add the Google Maps API key to the Android/iOS application configuration.

### 4. Configure ESP32

Program the ESP32 with the embedded C++ firmware and configure the required network and backend communication parameters.

### 5. Run the Application

```bash
flutter run
```

## Project Status

**Completed and Demonstrated**

VoltSwap has been fully developed as an integrated **Flutter + Supabase + ESP32 IoT system** and successfully demonstrated using a working hardware prototype.

The project demonstrates practical implementation of **embedded systems, IoT communication, cloud databases, mobile application development, real-time data synchronization, and hardware–software integration** for an EV battery-swapping application.

