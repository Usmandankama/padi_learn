import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  String? _selectedCategory;
  File? _videoFile;
  File? _thumbnailFile; // For custom thumbnail
  bool _isLoading = false;

  final List<String> _categories = [
    'Programming',
    'Design',
    'Marketing',
    'Business',
    'Data Science',
  ];

  Future<void> _pickVideo() async {
    final pickedFile =
        await ImagePicker().pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _thumbnailFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_videoFile == null || _thumbnailFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both a video and a thumbnail'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload the video to Firebase Storage
      final userId =
          FirebaseAuth.instance.currentUser!.uid; // Get the current user's ID

      // Upload the video
      final videoStorageRef = FirebaseStorage.instance.ref().child(
          'courses_videos/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4');
      final videoUploadTask = videoStorageRef.putFile(_videoFile!);
      final videoSnapshot = await videoUploadTask;
      final videoUrl = await videoSnapshot.ref.getDownloadURL();

      // Upload the thumbnail
      final thumbnailStorageRef = FirebaseStorage.instance.ref().child(
          'courses_thumbnails/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final thumbnailUploadTask = thumbnailStorageRef.putFile(_thumbnailFile!);
      final thumbnailSnapshot = await thumbnailUploadTask;
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

      // Save the course information to Firestore
      await FirebaseFirestore.instance.collection('courses').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'category': _selectedCategory,
        'author': _authorController.text.trim(),
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl, // Save the thumbnail URL
        'userId': userId, // Associate this course with the current user
        'createdAt': Timestamp.now(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully!')),
      );

      // Clear the form
      _formKey.currentState!.reset();
      setState(() {
        _videoFile = null;
        _thumbnailFile = null;
        _selectedCategory = null;
      });
      // Navigate back to the CoursesScreen
      Navigator.pop(context);
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
          style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0.w, vertical: 16.0.h),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Course Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Course Title',
                  labelStyle: TextStyle(fontSize: 16.sp),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),

              // Course Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Course Description',
                  labelStyle: TextStyle(fontSize: 16.sp),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
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

              // Course Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category, style: TextStyle(fontSize: 16.sp)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              TextFormField(
                keyboardType: TextInputType.number,
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Input Price',
                  labelStyle: TextStyle(fontSize: 16.sp),
                  
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course price';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _authorController,
                decoration: InputDecoration(
                  labelText: 'Author Name',
                  labelStyle: TextStyle(fontSize: 16.sp),
                  
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter author name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              // Upload Video Button
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: Icon(Icons.video_library,
                    size: 24.sp, color: AppColors.primaryColor),
                label: Text(
                  'Upload Video',
                  style:
                      TextStyle(fontSize: 16.sp, color: AppColors.primaryColor),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  backgroundColor: AppColors.lightGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),

              // Show selected video file if available
              if (_videoFile != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryColor),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Selected video: ${_videoFile!.path.split('/').last}',
                          style: TextStyle(
                              fontSize: 14.sp, color: AppColors.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 20.h),

              // Upload Thumbnail Button
              ElevatedButton.icon(
                onPressed: _pickThumbnail,
                icon: Icon(Icons.image,
                    size: 24.sp, color: AppColors.primaryColor),
                label: Text(
                  'Upload Thumbnail',
                  style:
                      TextStyle(fontSize: 16.sp, color: AppColors.primaryColor),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  backgroundColor: AppColors.lightGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),

              // Show selected thumbnail file if available
              if (_thumbnailFile != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryColor),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Selected thumbnail: ${_thumbnailFile!.path.split('/').last}',
                          style: TextStyle(
                              fontSize: 14.sp, color: AppColors.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 20.h),

              // Create Course Button with Loading Indicator
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadCourse,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Create Course',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.appWhite,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
