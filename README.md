<h2>🩺 Health & Mental Wellbeing Monitoring App</h2>

This project is a mobile health monitoring application designed to collect, analyze, and visualize physiological and mental health indicators using data from wearable devices.
The system aims to provide continuous health tracking, mental health assessment, and personalized insights to improve users’ overall well-being.

<h2>🔍 Project Overview</h2>

The application integrates with Android Health Connect to retrieve vital health data such as heart rate, heart rate variability (HRV), sleep patterns, physical activity, blood oxygen level, blood pressure, and blood glucose (manual input).
All data processing and analysis are performed in the cloud, ensuring scalability, efficiency, and device-independent computation.

<h2>🧠 Mental Health Assessment</h2>

Mental health status is evaluated using Heart Rate Variability (HRV) metrics, specifically SDNN and RMSSD, which are scientifically associated with stress, emotional regulation, and mental well-being.
When abnormal or prolonged reductions in HRV are detected, the system generates alerts and provides supportive feedback.

<h2>🤖 Machine Learning & Analysis</h2>

The project employs machine learning models to:

Analyze health and activity patterns

Assess physical and mental health status

Predict potential health risks

Generate personalized insights and notifications

Pre-trained models (e.g., depression classification based on DASS-42 data) are deployed via external APIs and queried periodically.

<h2>☁️ System Architecture</h2>

Frontend: Flutter mobile application

Health Data Source: Android Health Connect

Backend & Storage: Firebase (Authentication, Firestore)

Background Tasks: WorkManager & AlarmManager

AI Services: Cloud-hosted ML models (Hugging Face / OpenRouter APIs)

Notifications: Local and scheduled smart notifications

<h2>🎯 Key Features</h2>

Continuous health data synchronization

Cloud-based analysis and reporting

Mental health monitoring using HRV indicators

Personalized health and mental health reports

Secure user authentication

Automated background processing

Dark mode support

<h2>📌 Purpose</h2>

This project demonstrates the practical application of digital health technologies, wearable data analysis, and artificial intelligence to support proactive health monitoring and early mental health awareness.

<img width="300" height="300"  alt="health-care" src="https://github.com/user-attachments/assets/77708bf9-9dec-4280-9af3-ba9cad6ce26c" />


