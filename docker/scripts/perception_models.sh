# Perception model weights, shared by dev_start.sh and
# publish_perception_models.sh. Apollo publishes them only on the Baidu
# servers (scripts/model_download.sh, buildtool packages); we mirror all of
# them on Hugging Face. One weight file per model marks it present.
#
# Not listed: cpdet, efficient_net, pointwise_unet, tl_detection_yolox and
# yolox_garbage_onnx. Apollo ships no weights for them (their packages are
# empty on every server), so there is nothing to mirror.
#
# Loaded by the default configs: center_point_paddle (lidar_detection),
# 3d-r4-half_caffe (camera_detection_multi_stage, front_6mm),
# tl_detection_caffe and vertical/quadrate/horizontal_caffe (traffic lights).
PERCEPTION_MODELS_DIR="modules/perception/data/models"
PERCEPTION_MODELS_ARCHIVE="perception-models-11.0.tar.gz"
PERCEPTION_MODEL_WEIGHTS=(
  3d-r4-half_caffe/deploy.model
  center_point_paddle/centerpoint.pdiparams
  cnnseg128_caffe/deploy.caffemodel
  cnnseg16_caffe/deploy.caffemodel
  cnnseg64_caffe/deploy.caffemodel
  horizontal_caffe/baidu_iter_200000.caffemodel
  mask_pillars_torch/maskpillars.zip
  point_pillars_radar4d_torch/radar_libtorch_all.zip
  point_pillars_torch/pointpillars.zip
  quadrate_caffe/baidu_iter_200000.caffemodel
  smoke_torch/smoke_libtorch_model.pth
  tl_detection_caffe/baidu_iter_140000.caffemodel
  vertical_caffe/baidu_iter_250000.caffemodel
  yolox3d_onnx/yolo_onnx_model_3d.onnx
)
