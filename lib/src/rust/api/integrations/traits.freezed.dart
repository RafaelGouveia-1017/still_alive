// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'traits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$IntegrationRecord {

 String get id;
/// Create a copy of IntegrationRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IntegrationRecordCopyWith<IntegrationRecord> get copyWith => _$IntegrationRecordCopyWithImpl<IntegrationRecord>(this as IntegrationRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IntegrationRecord&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'IntegrationRecord(id: $id)';
}


}

/// @nodoc
abstract mixin class $IntegrationRecordCopyWith<$Res>  {
  factory $IntegrationRecordCopyWith(IntegrationRecord value, $Res Function(IntegrationRecord) _then) = _$IntegrationRecordCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$IntegrationRecordCopyWithImpl<$Res>
    implements $IntegrationRecordCopyWith<$Res> {
  _$IntegrationRecordCopyWithImpl(this._self, this._then);

  final IntegrationRecord _self;
  final $Res Function(IntegrationRecord) _then;

/// Create a copy of IntegrationRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [IntegrationRecord].
extension IntegrationRecordPatterns on IntegrationRecord {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( IntegrationRecord_User value)?  user,TResult Function( IntegrationRecord_Channel value)?  channel,required TResult orElse(),}){
final _that = this;
switch (_that) {
case IntegrationRecord_User() when user != null:
return user(_that);case IntegrationRecord_Channel() when channel != null:
return channel(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( IntegrationRecord_User value)  user,required TResult Function( IntegrationRecord_Channel value)  channel,}){
final _that = this;
switch (_that) {
case IntegrationRecord_User():
return user(_that);case IntegrationRecord_Channel():
return channel(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( IntegrationRecord_User value)?  user,TResult? Function( IntegrationRecord_Channel value)?  channel,}){
final _that = this;
switch (_that) {
case IntegrationRecord_User() when user != null:
return user(_that);case IntegrationRecord_Channel() when channel != null:
return channel(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String username)?  user,TResult Function( String id,  String name,  String? guildId,  String? guildName)?  channel,required TResult orElse(),}) {final _that = this;
switch (_that) {
case IntegrationRecord_User() when user != null:
return user(_that.id,_that.username);case IntegrationRecord_Channel() when channel != null:
return channel(_that.id,_that.name,_that.guildId,_that.guildName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String username)  user,required TResult Function( String id,  String name,  String? guildId,  String? guildName)  channel,}) {final _that = this;
switch (_that) {
case IntegrationRecord_User():
return user(_that.id,_that.username);case IntegrationRecord_Channel():
return channel(_that.id,_that.name,_that.guildId,_that.guildName);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String username)?  user,TResult? Function( String id,  String name,  String? guildId,  String? guildName)?  channel,}) {final _that = this;
switch (_that) {
case IntegrationRecord_User() when user != null:
return user(_that.id,_that.username);case IntegrationRecord_Channel() when channel != null:
return channel(_that.id,_that.name,_that.guildId,_that.guildName);case _:
  return null;

}
}

}

/// @nodoc


class IntegrationRecord_User extends IntegrationRecord {
  const IntegrationRecord_User({required this.id, required this.username}): super._();
  

@override final  String id;
 final  String username;

/// Create a copy of IntegrationRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IntegrationRecord_UserCopyWith<IntegrationRecord_User> get copyWith => _$IntegrationRecord_UserCopyWithImpl<IntegrationRecord_User>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IntegrationRecord_User&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username));
}


@override
int get hashCode => Object.hash(runtimeType,id,username);

@override
String toString() {
  return 'IntegrationRecord.user(id: $id, username: $username)';
}


}

/// @nodoc
abstract mixin class $IntegrationRecord_UserCopyWith<$Res> implements $IntegrationRecordCopyWith<$Res> {
  factory $IntegrationRecord_UserCopyWith(IntegrationRecord_User value, $Res Function(IntegrationRecord_User) _then) = _$IntegrationRecord_UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String username
});




}
/// @nodoc
class _$IntegrationRecord_UserCopyWithImpl<$Res>
    implements $IntegrationRecord_UserCopyWith<$Res> {
  _$IntegrationRecord_UserCopyWithImpl(this._self, this._then);

  final IntegrationRecord_User _self;
  final $Res Function(IntegrationRecord_User) _then;

/// Create a copy of IntegrationRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,}) {
  return _then(IntegrationRecord_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class IntegrationRecord_Channel extends IntegrationRecord {
  const IntegrationRecord_Channel({required this.id, required this.name, this.guildId, this.guildName}): super._();
  

@override final  String id;
 final  String name;
 final  String? guildId;
 final  String? guildName;

/// Create a copy of IntegrationRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IntegrationRecord_ChannelCopyWith<IntegrationRecord_Channel> get copyWith => _$IntegrationRecord_ChannelCopyWithImpl<IntegrationRecord_Channel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IntegrationRecord_Channel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.guildId, guildId) || other.guildId == guildId)&&(identical(other.guildName, guildName) || other.guildName == guildName));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,guildId,guildName);

@override
String toString() {
  return 'IntegrationRecord.channel(id: $id, name: $name, guildId: $guildId, guildName: $guildName)';
}


}

/// @nodoc
abstract mixin class $IntegrationRecord_ChannelCopyWith<$Res> implements $IntegrationRecordCopyWith<$Res> {
  factory $IntegrationRecord_ChannelCopyWith(IntegrationRecord_Channel value, $Res Function(IntegrationRecord_Channel) _then) = _$IntegrationRecord_ChannelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? guildId, String? guildName
});




}
/// @nodoc
class _$IntegrationRecord_ChannelCopyWithImpl<$Res>
    implements $IntegrationRecord_ChannelCopyWith<$Res> {
  _$IntegrationRecord_ChannelCopyWithImpl(this._self, this._then);

  final IntegrationRecord_Channel _self;
  final $Res Function(IntegrationRecord_Channel) _then;

/// Create a copy of IntegrationRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? guildId = freezed,Object? guildName = freezed,}) {
  return _then(IntegrationRecord_Channel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,guildId: freezed == guildId ? _self.guildId : guildId // ignore: cast_nullable_to_non_nullable
as String?,guildName: freezed == guildName ? _self.guildName : guildName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
