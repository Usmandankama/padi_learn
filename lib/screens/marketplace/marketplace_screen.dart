import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'components/courseGrid.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  _MarketplaceScreenState createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late Future<List<QueryDocumentSnapshot>> _courses;
  String searchQuery = '';
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _courses = _fetchAllCourses(); // Fetch all courses from Firestore
  }

  Future<List<QueryDocumentSnapshot>> _fetchAllCourses() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('courses').get();
    return querySnapshot.docs;
  }

  // Function to filter courses by search query
  List<QueryDocumentSnapshot> _filterCourses(List<QueryDocumentSnapshot> courses) {
    return courses.where((course) {
      final courseData = course.data() as Map<String, dynamic>;
      final title = courseData['title'].toString().toLowerCase();
      return title.contains(searchQuery.toLowerCase()) &&
          (selectedFilter == 'All' || courseData['category'] == selectedFilter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {
              // Handle filter actions
            },
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          // Search Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Dropdown filter for category
                DropdownButton<String>(
                  value: selectedFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedFilter = newValue!;
                    });
                  },
                  items: <String>['All', 'Programming', 'Design', 'Marketing']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Display the courses in a GridView
          Expanded(
            child: FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _courses,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading courses'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No courses available'));
                }

                // Apply search and filter
                final filteredCourses = _filterCourses(snapshot.data!);

                return CoursesGrid(courses: filteredCourses);
              },
            ),
          ),
        ],
      ),
    );
  }
}
