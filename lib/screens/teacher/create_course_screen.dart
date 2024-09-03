// create_course_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/utils/colors.dart'; // Adjust this import based on your project structure

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  _CreateCourseScreenState createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _videoFile;
  bool _isLoading = false;

  Future<void> _pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a video to upload')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload the video to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('courses_videos/${DateTime.now().millisecondsSinceEpoch}.mp4');
      final uploadTask = storageRef.putFile(_videoFile!);

      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();

      // Save the course information to Firestore
      await FirebaseFirestore.instance.collection('courses').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'videoUrl': videoUrl,
        'createdAt': Timestamp.now(),
        // Add other necessary fields like teacher ID, etc.
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course created successfully!')),
      );

      // Clear the form
      _formKey.currentState!.reset();
      setState(() {
        _videoFile = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create course: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Course',
          style: TextStyle(color: AppColors.primaryColor),
        ),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0.w),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Course Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Course Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: Icon(Icons.video_library),
                label: Text('Upload Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
              if (_videoFile != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Text(
                    'Selected video: ${_videoFile!.path.split('/').last}',
                    style: TextStyle(fontSize: 14.sp, color: AppColors.primaryColor),
                  ),
                ),
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadCourse,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Create Course'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.0.h),
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
