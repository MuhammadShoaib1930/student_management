import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p; // Use alias to avoid conflict

void main() {
  runApp(const StudentManagementApp());
}

class StudentManagementApp extends StatelessWidget {
  const StudentManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Management',
      home: StudentListPage(),
    );
  }
}

class Student {
  final int? id;
  final String name;
  final String rollNumber;
  final String department;
  final String semester;

  Student({
    this.id,
    required this.name,
    required this.rollNumber,
    required this.department,
    required this.semester,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
      'department': department,
      'semester': semester,
    };
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('students.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName); // Use 'p.join' instead of 'join'

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rollNumber TEXT NOT NULL,
        department TEXT NOT NULL,
        semester TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertStudent(Student student) async {
    final db = await instance.database;
    return await db.insert('students', student.toMap());
  }

  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Student>> getAllStudents() async {
    final db = await instance.database;
    final result = await db.query('students');

    return result
        .map((json) => Student(
              id: json['id'] as int,
              name: json['name'] as String,
              rollNumber: json['rollNumber'] as String,
              department: json['department'] as String,
              semester: json['semester'] as String,
            ))
        .toList();
  }
}

class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  _StudentListPageState createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  List<Student> _students = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _semesterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final students = await DatabaseHelper.instance.getAllStudents();
    setState(() {
      _students = students;
    });
  }

  void _showStudentDialog({Student? student}) {
    if (student != null) {
      _nameController.text = student.name;
      _rollNumberController.text = student.rollNumber;
      _departmentController.text = student.department;
      _semesterController.text = student.semester;
    } else {
      _nameController.clear();
      _rollNumberController.clear();
      _departmentController.clear();
      _semesterController.clear();
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(student == null ? 'Add Student' : 'Edit Student'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                TextFormField(
                  controller: _rollNumberController,
                  decoration: const InputDecoration(labelText: 'Roll Number'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a roll number' : null,
                ),
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                TextFormField(
                  controller: _semesterController,
                  decoration: const InputDecoration(labelText: 'Semester'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final newStudent = Student(
                    id: student?.id,
                    name: _nameController.text,
                    rollNumber: _rollNumberController.text,
                    department: _departmentController.text,
                    semester: _semesterController.text,
                  );

                  if (student == null) {
                    await DatabaseHelper.instance.insertStudent(newStudent);
                  } else {
                    await DatabaseHelper.instance.updateStudent(newStudent);
                  }

                  Navigator.pop(dialogContext);
                  _loadStudents();
                }
              },
              child: Text(student == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
      ),
      body: _students.isEmpty
          ? const Center(child: Text('No students found.'))
          : ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Card(
                  child: ListTile(
                    title: Text(student.name),
                    subtitle: Text(
                        'Roll: ${student.rollNumber}, Dept: ${student.department}, Sem: ${student.semester}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showStudentDialog(student: student),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance
                                .deleteStudent(student.id!);
                            _loadStudents();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showStudentDialog(),
      ),
    );
  }
}
