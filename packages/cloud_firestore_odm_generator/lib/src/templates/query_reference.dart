// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';

import '../collection_data.dart';
import '../collection_generator.dart';

class _FilterOperator {
  const _FilterOperator({
    required this.name,
    required this.type,
    required this.mapper,
  });

  final String name;
  final String type;
  final String Function(String) mapper;
}

class _WherePrototype {
  _WherePrototype({
    required this.call,
  });

  _WherePrototype.plain(String type, [String? defaultValue])
      : call = ((name) {
          if (defaultValue != null) {
            return '$type $name = $defaultValue,';
          }
          return '$type $name,';
        });

  final String Function(String name) call;
}

class _WhereMapper {
  _WhereMapper({required this.prototype, required this.map});
  _WhereMapper.identity({required this.prototype}) : map = ((name) => name);

  final _WherePrototype prototype;
  final String Function(String name) map;
}

extension on QueryingField {
  String get iterableType {
    return (type as InterfaceType).typeArguments.first.toString();
  }
}

class QueryTemplate {
  QueryTemplate(this.data);

  final CollectionData data;

  @override
  String toString() {
    return '''
abstract class ${data.queryReferenceInterfaceName} implements QueryReference<${data.type}, ${data.querySnapshotName}> {
  @override
  ${data.queryReferenceInterfaceName} limit(int limit);

  @override
  ${data.queryReferenceInterfaceName} limitToLast(int limit);

  ${_where(data, isAbstract: true)}
  ${_orderByProto(data)}
}

class ${data.queryReferenceImplName}
    extends QueryReference<${data.type}, ${data.querySnapshotName}>
    implements ${data.queryReferenceInterfaceName} {
  ${data.queryReferenceImplName}(
    this._collection, {
    required Query<${data.type}> \$referenceWithoutCursor,
    \$QueryCursor \$queryCursor = const \$QueryCursor(),
  })  : super(
          \$referenceWithoutCursor: \$referenceWithoutCursor,
          \$queryCursor: \$queryCursor,
        );

  final CollectionReference<Object?> _collection;

  @override
  Stream<${data.querySnapshotName}> snapshots([SnapshotOptions? options]) {
    return reference.snapshots().map(${data.querySnapshotName}._fromQuerySnapshot);
  }
  

  @override
  Future<${data.querySnapshotName}> get([GetOptions? options]) {
    return reference.get(options).then(${data.querySnapshotName}._fromQuerySnapshot);
  }

  @override
  ${data.queryReferenceInterfaceName} limit(int limit) {
    return ${data.queryReferenceImplName}(
      _collection,
      \$referenceWithoutCursor: \$referenceWithoutCursor.limit(limit),
      \$queryCursor: \$queryCursor,
    );
  }

  @override
  ${data.queryReferenceInterfaceName} limitToLast(int limit) {
    return ${data.queryReferenceImplName}(
      _collection,
      \$referenceWithoutCursor: \$referenceWithoutCursor.limitToLast(limit),
      \$queryCursor: \$queryCursor,
    );
  }

  ${_where(data)}
  ${_orderBy(data)}

  ${_equalAndHashCode(data)}
}

${_firestoreFilter()}
''';
  }

  String _orderByProto(CollectionData data) {
    final buffer = StringBuffer();

    for (final field in data.queryableFields) {
      final titledNamed = field.name.replaceFirstMapped(
        RegExp('[a-zA-Z]'),
        (match) => match.group(0)!.toUpperCase(),
      );

      final positionalFields = [
        if (field.name == 'fieldPath') '${field.type} fieldPath,',
      ].join();

      buffer.writeln(
        '''
  ${field.orderByDoc}
  ${data.queryReferenceInterfaceName} orderBy$titledNamed($positionalFields {
    bool descending = false,
    ${field.type.getDisplayString(withNullability: true)} startAt,
    ${field.type.getDisplayString(withNullability: true)} startAfter,
    ${field.type.getDisplayString(withNullability: true)} endAt,
    ${field.type.getDisplayString(withNullability: true)} endBefore,
    ${data.documentSnapshotName}? startAtDocument,
    ${data.documentSnapshotName}? endAtDocument,
    ${data.documentSnapshotName}? endBeforeDocument,
    ${data.documentSnapshotName}? startAfterDocument,
  });
''',
      );
    }

    return buffer.toString();
  }

  String _orderBy(CollectionData data) {
    final buffer = StringBuffer();

    for (final field in data.queryableFields) {
      final titledNamed = field.name.replaceFirstMapped(
        RegExp('[a-zA-Z]'),
        (match) => match.group(0)!.toUpperCase(),
      );

      final positionalFields = [
        if (field.name == 'fieldPath') '${field.type} fieldPath,',
      ].join();

      buffer.writeln(
        '''
  @override
  ${data.queryReferenceInterfaceName} orderBy$titledNamed($positionalFields {
    bool descending = false,
    Object? startAt = _sentinel,
    Object? startAfter = _sentinel,
    Object? endAt = _sentinel,
    Object? endBefore = _sentinel,
    ${data.documentSnapshotName}? startAtDocument,
    ${data.documentSnapshotName}? endAtDocument,
    ${data.documentSnapshotName}? endBeforeDocument,
    ${data.documentSnapshotName}? startAfterDocument,
  }) {
    final query = \$referenceWithoutCursor.orderBy(${field.field}, descending: descending);
    var queryCursor = \$queryCursor;

    if (startAtDocument != null) {
      queryCursor = queryCursor.copyWith(
        startAt: const [],
        startAtDocumentSnapshot: startAtDocument.snapshot,
      );
    }
    if (startAfterDocument != null) {
      queryCursor = queryCursor.copyWith(
        startAfter: const [],
        startAfterDocumentSnapshot: startAfterDocument.snapshot,
      );
    }
    if (endAtDocument != null) {
      queryCursor = queryCursor.copyWith(
        endAt: const [],
        endAtDocumentSnapshot: endAtDocument.snapshot,
      );
    }
    if (endBeforeDocument != null) {
      queryCursor = queryCursor.copyWith(
        endBefore: const [],
        endBeforeDocumentSnapshot: endBeforeDocument.snapshot,
      );
    }

    if (startAt != _sentinel) {
      queryCursor = queryCursor.copyWith(
        startAt: [...queryCursor.startAt, startAt],
        startAtDocumentSnapshot: null,
      );
    }
    if (startAfter != _sentinel) {
      queryCursor = queryCursor.copyWith(
        startAfter: [...queryCursor.startAfter, startAfter],
        startAfterDocumentSnapshot: null,
      );
    }
    if (endAt != _sentinel) {
      queryCursor = queryCursor.copyWith(
        endAt: [...queryCursor.endAt, endAt],
        endAtDocumentSnapshot: null,
      );
    }
    if (endBefore != _sentinel) {
      queryCursor = queryCursor.copyWith(
        endBefore: [...queryCursor.endBefore, endBefore],
        endBeforeDocumentSnapshot: null,
      );
    }

    return ${data.queryReferenceImplName}(
      _collection,
      \$referenceWithoutCursor: query,
      \$queryCursor: queryCursor,
    );
  }
''',
      );
    }

    return buffer.toString();
  }

  String _where(CollectionData data, {bool isAbstract = false}) {
    final buffer = StringBuffer();

    for (final field in data.queryableFields) {
      final titledNamed = field.name.replaceFirstMapped(
        RegExp('[a-zA-Z]'),
        (match) => match.group(0)!.toUpperCase(),
      );

      final nullableType =
          field.type.nullabilitySuffix == NullabilitySuffix.question
              ? '${field.type}'
              : '${field.type}?';

      final nullableWhereType = _WherePrototype.plain(nullableType);
      final sentinelObjectWhereType =
          _WherePrototype.plain('Object?', '_sentinel');
      final objectWhereType = _WherePrototype.plain('Object?');

      final perFieldToJson = data.perFieldToJson(field.name);
      String valueToJson(String name, {String? cast}) {
        if (field.name == 'documentId' || field.name == 'fieldPath') {
          return name;
        }

        final trailing = cast != null ? ' as $cast' : '';

        return '$perFieldToJson($name$trailing)';
      }

      final equalToMapper = _WhereMapper(
        prototype: isAbstract ? nullableWhereType : sentinelObjectWhereType,
        map: (name) {
          final mapped = valueToJson(name, cast: field.type.toString());
          return '$name != _sentinel ? $mapped : null';
        },
      );
      final compareMapper = _WhereMapper(
        prototype: isAbstract ? nullableWhereType : objectWhereType,
        map: (name) {
          final mapped = valueToJson(name, cast: field.type.toString());
          // remove redundant ternary when there is no FieldMap
          if (mapped == name) return name;
          return '$name != null ? $mapped : null';
        },
      );

      final inMapper = _WhereMapper(
        prototype: _WherePrototype.plain('List<${field.type}>?'),
        map: (name) => '$name?.map((e) => ${valueToJson('e')})',
      );

      final operators = <String, _WhereMapper>{
        'isEqualTo': equalToMapper,
        'isNotEqualTo': equalToMapper,
        'isLessThan': compareMapper,
        'isLessThanOrEqualTo': compareMapper,
        'isGreaterThan': compareMapper,
        'isGreaterThanOrEqualTo': compareMapper,
        if (field.name == 'documentId') ...{
          'whereIn': _WhereMapper.identity(
            prototype: _WherePrototype.plain('List<String>?'),
          ),
          'whereNotIn': _WhereMapper.identity(
            prototype: _WherePrototype.plain('List<String>?'),
          ),
        } else if (field.name == 'fieldPath') ...{
          'arrayContains': _WhereMapper.identity(
            prototype: _WherePrototype.plain('Object?'),
          ),
          'arrayContainsAny': _WhereMapper.identity(
            prototype: _WherePrototype.plain('List<Object?>?'),
          ),
          'whereIn': _WhereMapper.identity(
            prototype: _WherePrototype.plain('List<Object?>?'),
          ),
          'whereNotIn': _WhereMapper.identity(
            prototype: _WherePrototype.plain('List<Object?>?'),
          ),
        } else if (field.type.isSupportedIterable) ...{
          'arrayContains': _WhereMapper(
            prototype: isAbstract
                ? _WherePrototype.plain(
                    data.libraryElement.typeProvider
                        .asNullable(
                          (field.type as InterfaceType).typeArguments.first,
                        )
                        .toString(),
                  )
                : objectWhereType,
            map: (name) {
              final itemType = field.name == 'fieldPath'
                  ? field.type.toString()
                  : field.iterableType;
              final cast = itemType != 'Object?' ? ' as $itemType' : '';

              var transform = '$name != null ? ($perFieldToJson(';
              if (field.type.isSet) {
                transform += '{$name$cast}';
              } else {
                transform += '[$name$cast]';
              }
              return '$transform) as List?)!.single : null';
            },
          ),
          'arrayContainsAny': _WhereMapper(
            prototype: nullableWhereType,
            map: (name) =>
                '$name != null ? $perFieldToJson($name) as Iterable<Object>? : null',
          ),
        } else if (!field.type.isSupportedIterable) ...{
          'whereIn': inMapper,
          'whereNotIn': inMapper,
        },
        'isNull': _WhereMapper(
          prototype: _WherePrototype.plain('bool?'),
          map: (name) => 'isNull',
        ),
      };

      final prototype =
          operators.entries.map((e) => e.value.prototype.call(e.key)).join();

      final parameters = operators.entries.map((entry) {
        final key = entry.key;
        final value = entry.value;

        return '$key: ${value.map.call(key)},';
      }).join();

      final positionalFields = [
        if (field.name == 'fieldPath') '${field.type} fieldPath,',
      ].join();

      if (isAbstract) {
        buffer.writeln(
          '''
${field.whereDoc}
${data.queryReferenceInterfaceName} where$titledNamed($positionalFields {$prototype});''',
        );
      } else {
        buffer.writeln(
          '''
  @override
  ${data.queryReferenceInterfaceName} where$titledNamed($positionalFields {$prototype}) {
    return ${data.queryReferenceImplName}(
      _collection,
      \$referenceWithoutCursor: \$referenceWithoutCursor.where(${field.field}, $parameters),
      \$queryCursor: \$queryCursor,
    );
  }
''',
        );
      }
    }

    if (isAbstract) {
      buffer.writeln(
        '''

${data.queryReferenceInterfaceName} whereFirestoreFilter(Filter filter);
''',
      );
    } else {
      buffer.writeln(
        '''

  ${data.queryReferenceInterfaceName} whereFirestoreFilter(Filter filter) {
    return ${data.queryReferenceImplName}(
      _collection,
      \$referenceWithoutCursor: \$referenceWithoutCursor.where(filter),
      \$queryCursor: \$queryCursor,
    );
  }
''',
      );
    }

    return buffer.toString();
  }

  String _equalAndHashCode(CollectionData data) {
    final propertyNames = [
      'runtimeType',
      'reference',
    ];

    return '''
  @override
  bool operator ==(Object other) {
    return other is ${data.queryReferenceImplName}
      && ${propertyNames.map((p) => 'other.$p == $p').join(' && ')};
  }

  @override
  int get hashCode => Object.hash(${propertyNames.join(', ')});
''';
  }

  String _firestoreFilter() {
    final buffer = StringBuffer();

    final classPrefix = data.classPrefix;
    final filterClassName = '${classPrefix}Filter';

    buffer.writeln(
      '''
class $filterClassName {
  $filterClassName._();

  ${_firestoreFilterFieldsConstructors()}
}
''',
    );

    return buffer.toString();
  }

  String _firestoreFilterFieldsConstructors() {
    final buffer = StringBuffer();

    for (final field in data.queryableFields) {
      final name = field.name;
      if (name == 'documentId' || name == 'fieldPath') {
        continue;
      }

      final perFieldToJson = data.perFieldToJson(field.name);
      String valueToJson(String name) => '$perFieldToJson($name)';
      String equalToMapper(String name) =>
          'value == null ? null : ${valueToJson('value')}';
      String iterableMapper(String name) =>
          'value.map((e) => e == null ? null : ${valueToJson('e')})';
      String boolMapper(String name) => 'value';

      final fieldType =
          field.type.nullabilitySuffix == NullabilitySuffix.question
              ? '${field.type}'
              : '${field.type}?';

      final operators = [
        _FilterOperator(
          name: 'isEqualTo',
          type: fieldType,
          mapper: equalToMapper,
        ),
        _FilterOperator(
          name: 'isNotEqualTo',
          type: fieldType,
          mapper: equalToMapper,
        ),
        _FilterOperator(
          name: 'isLessThan',
          type: fieldType,
          mapper: equalToMapper,
        ),
        _FilterOperator(
          name: 'isLessThanOrEqualTo',
          type: fieldType,
          mapper: equalToMapper,
        ),
        _FilterOperator(
          name: 'isGreaterThan',
          type: fieldType,
          mapper: equalToMapper,
        ),
        _FilterOperator(
          name: 'isGreaterThanOrEqualTo',
          type: fieldType,
          mapper: equalToMapper,
        ),
        if (field.type.isSupportedIterable) ...[
          _FilterOperator(
            name: 'arrayContains',
            type: field.iterableType,
            mapper: (value) {
              var transform = '($perFieldToJson(';
              if (field.type.isSet) {
                transform += '{value}';
              } else {
                transform += '[value]';
              }
              return '$transform) as List?)!.single';
            },
          ),
          _FilterOperator(
            name: 'arrayContainsAny',
            type: 'Iterable<$fieldType>',
            mapper: iterableMapper,
          ),
        ] else ...[
          _FilterOperator(
            name: 'whereIn',
            type: 'Iterable<$fieldType>',
            mapper: iterableMapper,
          ),
          _FilterOperator(
            name: 'whereNotIn',
            type: 'Iterable<$fieldType>',
            mapper: iterableMapper,
          ),
        ],
        _FilterOperator(name: 'isNull', type: 'bool', mapper: boolMapper),
      ];

      for (final operator in operators) {
        final nameSuffix = operator.name.replaceFirstMapped(
          RegExp('[a-zA-Z]'),
          (match) => match.group(0)!.toUpperCase(),
        );

        buffer.writeln('''
  static Filter $name$nameSuffix(${operator.type} value) => 
      Filter(${field.field}, ${operator.name}: ${operator.mapper('value')});
''');
      }
    }

    return buffer.toString();
  }
}

extension on TypeProvider {
  DartType asNullable(DartType type) {
    final typeSystem = nullType.element.library.typeSystem;
    if (typeSystem.isNullable(type)) return type;

    return typeSystem.leastUpperBound(type, nullType);
  }
}
