using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.SDK3.Image;
using VRC.SDK3.Components;
using VRC.Udon.Common.Interfaces;
using JLChnToZ.VRC;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SimpleImageLoader : UdonSharpBehaviour {
    [SerializeField] Text statusText;
    [SerializeField] RawImage imageDisplay;
    AspectRatioFitter sizeFitter;
    [SerializeField, BindEvent(nameof(VRCUrlInputField.onEndEdit), nameof(_UpdateUrl))]
    VRCUrlInputField urlInputField;
    [UdonSynced, FieldChangeCallback(nameof(URL))] VRCUrl url;
    VRCImageDownloader loader;
    IVRCImageDownload imageToLoad;
    bool isLoading;

    public VRCUrl URL {
        get => url;
        set {
            url = value;
            urlInputField.SetUrl(url);
            if (string.IsNullOrEmpty(url.Get())) return;
            if (!Utilities.IsValid(loader)) loader = new VRCImageDownloader();
            isLoading = true;
            imageToLoad = loader.DownloadImage(url, null, (IUdonEventReceiver)this);
            statusText.text = "Loading";
            imageDisplay.gameObject.SetActive(false);
            SendCustomEventDelayedFrames(nameof(_OnImageDownloading), 0);
            if (Networking.IsOwner(gameObject)) RequestSerialization();
        }
    }

    void Start() {
        sizeFitter = imageDisplay.GetComponent<AspectRatioFitter>();
    }

    public override void OnImageLoadSuccess(IVRCImageDownload image) {
        isLoading = false;
        statusText.text = "";
        var texture = image.Result;
        imageDisplay.texture = texture;
        imageDisplay.gameObject.SetActive(true);
        sizeFitter.aspectRatio = (float)texture.width / texture.height;
    }

    public override void OnImageLoadError(IVRCImageDownload image) {
        isLoading = false;
        statusText.text = $"Error loading image: {image.ErrorMessage}";
    }

    public void _UpdateUrl() {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        URL = urlInputField.GetUrl();
    }

    public void _OnImageDownloading() {
        if (!isLoading) return;
        statusText.text = $"Loading {imageToLoad.Progress:P}";
        SendCustomEventDelayedFrames(nameof(_OnImageDownloading), 0);
    }
}
