import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/products_model.dart';

class ProductsRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<ProductsModel>>> getAll() async {
    try {
      final response = await _dio.get(ApiConstants.products);
      return ApiResponse.fromJson(
        response.data,
        (data) => (data as List).map((i) => ProductsModel.fromJson(i as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProductsModel>> create(String title, String description, double sellingPrice, double costPrice, String imageUrl) async {
    try {
      final response = await _dio.post(
        ApiConstants.createProduct,
        data: {'title': title, 'description': description,'selling_price': sellingPrice, 'cost_price': costPrice,'image_url': imageUrl},
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => ProductsModel.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<void>> delete(dynamic id) async {
    try {
      final response = await _dio.delete('${ApiConstants.productById}/$id');
      return ApiResponse.fromJson(response.data, (_) {});
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
