/*
The MIT License (MIT)

Copyright (c) 2023 Jeremy Lam aka. Vistanz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
using System;
#if UNITY_EDITOR
using System.Linq;
using System.Collections.Generic;
using System.Reflection;

using UnityEngine.Events;
using UnityEngine.SceneManagement;

using UnityEditor.Events;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;

using VRC.Udon;
using UdonSharp;
using UdonSharpEditor;

using UnityObject = UnityEngine.Object;
#endif

namespace JLChnToZ.VRC {

    [AttributeUsage(AttributeTargets.Field, AllowMultiple = true, Inherited = true)]
    public class BindEventAttribute : Attribute {
        public string Source { get; set; }
        public string Destination { get; set; }

        public BindEventAttribute(string source, string destination) {
            Source = source;
            Destination = destination;
        }
    }

    #if UNITY_EDITOR
    internal sealed class BindEventPreprocessor : IProcessSceneWithReport {
        readonly Dictionary<Type, FieldInfo[]> filteredFields = new Dictionary<Type, FieldInfo[]>();

        public int callbackOrder => 0;

        public void OnProcessScene(Scene scene, BuildReport report) {
            foreach (var usharp in scene.GetRootGameObjects().SelectMany(go => go.GetComponentsInChildren<UdonSharpBehaviour>(true))) {
                var fieldInfos = GetFields(usharp.GetType());
                if (fieldInfos.Length == 0) continue;
                var udon = UdonSharpEditorUtility.GetBackingUdonBehaviour(usharp);
                foreach (var field in fieldInfos) {
                    var targetObj = field.GetValue(usharp);
                    if (targetObj is Array array)
                        for (int i = 0, length = array.GetLength(0); i < length; i++)
                            ProcessEntry(array.GetValue(i) as UnityObject, field, udon, i);
                    else if (targetObj is UnityObject unityObject)
                        ProcessEntry(unityObject, field, udon, 0);
                }
            }
        }

        FieldInfo[] GetFields(Type type) {
            if (!filteredFields.TryGetValue(type, out var fieldInfos)) {
                fieldInfos = type.GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
                    .Where(field => field.IsDefined(typeof(BindEventAttribute), true)).ToArray();
                filteredFields[type] = fieldInfos;
            }
            return fieldInfos;
        }

        static void ProcessEntry(UnityObject targetObj, FieldInfo field, UdonBehaviour udon, int index) {
            if (targetObj == null) return;
            var objType = targetObj.GetType();
            foreach (var attribute in field.GetCustomAttributes<BindEventAttribute>(true))
                if (TryGetValue(targetObj, objType, attribute.Source, out var otherObj) && otherObj is UnityEventBase callback)
                    UnityEventTools.AddStringPersistentListener(callback, udon.SendCustomEvent, string.Format(attribute.Destination, index, targetObj.name));
        }

        static bool TryGetValue(object source, Type srcType, string fieldName, out object result) {
            var otherProp = srcType.GetProperty(fieldName, BindingFlags.Instance | BindingFlags.Public);
            if (otherProp != null) {
                result = otherProp.GetValue(source);
                return true;
            }
            var otherField = srcType.GetField(fieldName, BindingFlags.Instance | BindingFlags.Public);
            if (otherField != null) {
                result = otherField.GetValue(source);
                return true;
            }
            result = null;
            return false;
        }
    }
    #endif
}
