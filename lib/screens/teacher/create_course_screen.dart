import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/utils/colors.dart';

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
  File? _thumbnailFile;
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
    if (!_formKey.currentState!.validate()) return;

    if (_videoFile == null || _thumbnailFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both a video and a thumbnail')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Upload video
      final videoRef = FirebaseStorage.instance.ref(
          'courses_videos/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4');
      final videoSnap = await videoRef.putFile(_videoFile!);
      final videoUrl = await videoSnap.ref.getDownloadURL();

      // Upload thumbnail
      final thumbRef = FirebaseStorage.instance.ref(
          'courses_thumbnails/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final thumbSnap = await thumbRef.putFile(_thumbnailFile!);
      final thumbnailUrl = await thumbSnap.ref.getDownloadURL();

      // Create Firestore document with custom ID
      final docRef = FirebaseFirestore.instance.collection('courses').doc();
      await docRef.set({
        'id': docRef.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'category': _selectedCategory,
        'author': _authorController.text.trim(),
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'userId': userId,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully!')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _videoFile = null;
        _thumbnailFile = null;
        _selectedCategory = null;
      });

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
        title: Text('Create Course',
            style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold)),
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
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Course Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a course title'
                    : null,
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
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a course description'
                    : null,
              ),
              SizedBox(height: 20.h),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category, style: TextStyle(fontSize: 16.sp)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please select a category'
                    : null,
              ),
              SizedBox(height: 20.h),
              TextFormField(
                keyboardType: TextInputType.number,
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Input Price',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a course price'
                    : null,
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _authorController,
                decoration: InputDecoration(
                  labelText: 'Author Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter author name'
                    : null,
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: Icon(Icons.video_library, color: AppColors.primaryColor),
                label: Text('Upload Video',
                    style: TextStyle(color: AppColors.primaryColor)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              if (_videoFile != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Text(
                    'Selected video: ${_videoFile!.path.split('/').last}',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: _pickThumbnail,
                icon: Icon(Icons.image, color: AppColors.primaryColor),
                label: Text('Upload Thumbnail',
                    style: TextStyle(color: AppColors.primaryColor)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              if (_thumbnailFile != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Text(
                    'Selected thumbnail: ${_thumbnailFile!.path.split('/').last}',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Create Course',
                        style: TextStyle(
                            color: AppColors.appWhite, fontSize: 16.sp)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
