// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_odm/cloud_firestore_odm.dart';
import 'package:json_annotation/json_annotation.dart';

part 'simple2.g.dart';

enum Gender { male, female }

@Collection<Person>('models')
@JsonSerializable()
class Person {
  const Person(this.name, this.gender, this.childrenNames);

  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);

  final String name;
  final Gender gender;
  final List<String> childrenNames;

  Map<String, dynamic> toJson() => _$PersonToJson(this);
}
