#!/bin/bash
# 功能：生成与你提供的C++项目结构一致的空模板项目（采用核心库封装方案）
# 作者：自定义
# 用法：赋予执行权限后直接运行，按照提示输入信息即可

# ===================== 配置项（可根据需求修改默认值） =====================
DEFAULT_PROJECT_NAME="new_project"
DEFAULT_AUTHOR="Your Name <your.email@example.com>"
DEFAULT_CPP_STANDARD="17"  # 默认C++标准
DEFAULT_DESCRIPTION="A modern C++ project template based on CMake."
# ==========================================================================

# ===================== 工具函数 =====================
# 打印彩色信息
print_info() {
    echo -e "\033[34m[INFO] $1\033[0m"
}

print_success() {
    echo -e "\033[32m[SUCCESS] $1\033[0m"
}

print_warning() {
    echo -e "\033[33m[WARNING] $1\033[0m"
}

print_error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
}

# 检查目录是否存在，存在则退出
check_dir_exists() {
    if [ -d "$1" ]; then
        print_error "目录 $1 已存在，避免覆盖，脚本退出！"
        exit 1
    fi
}

# ===================== 用户交互 =====================
print_info "===== C++项目模板生成工具（修复CMake链接报错） ====="
read -p "请输入项目名称（默认：$DEFAULT_PROJECT_NAME）：" PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}

# 项目名称合法性检查（避免特殊字符）
if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    print_warning "项目名称包含特殊字符，可能会导致CMake构建问题，建议仅使用字母、数字、下划线"
    read -p "是否继续使用该名称？(y/n，默认y)：" CONTINUE
    CONTINUE=${CONTINUE:-y}
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        print_info "脚本退出，请重新输入合法项目名称"
        exit 0
    fi
fi

read -p "请输入作者信息（默认：$DEFAULT_AUTHOR）：" AUTHOR
AUTHOR=${AUTHOR:-$DEFAULT_AUTHOR}

read -p "请输入C++标准（默认：$DEFAULT_CPP_STANDARD）：" CPP_STANDARD
CPP_STANDARD=${CPP_STANDARD:-$DEFAULT_CPP_STANDARD}

read -p "请输入项目描述（默认：$DEFAULT_DESCRIPTION）：" DESCRIPTION
DESCRIPTION=${DESCRIPTION:-$DEFAULT_DESCRIPTION}

# ===================== 核心步骤：创建目录结构 =====================
print_info "开始创建项目目录结构..."
PROJECT_ROOT="./$PROJECT_NAME"

# 检查项目根目录是否存在
check_dir_exists "$PROJECT_ROOT"

# 递归创建目录（与你的项目结构完全一致）
mkdir -p \
    "$PROJECT_ROOT/assets" \
    "$PROJECT_ROOT/build" \
    "$PROJECT_ROOT/cmake" \
    "$PROJECT_ROOT/docs" \
    "$PROJECT_ROOT/examples" \
    "$PROJECT_ROOT/include/$PROJECT_NAME" \
    "$PROJECT_ROOT/lib/include" \
    "$PROJECT_ROOT/lib/lib" \
    "$PROJECT_ROOT/src/test" \
    "$PROJECT_ROOT/test" \
    "$PROJECT_ROOT/third_party"

print_success "目录结构创建完成"

# ===================== 核心步骤：生成模板文件（关键修改点） =====================
print_info "开始生成基础模板文件..."

# 1. 根目录 CMakeLists.txt（核心修改：封装核心静态库，避免链接报错）
cat > "$PROJECT_ROOT/CMakeLists.txt" << EOF
# CMake 最低版本要求
cmake_minimum_required(VERSION 3.10)

# 项目信息
project($PROJECT_NAME
    LANGUAGES CXX
    DESCRIPTION "$DESCRIPTION"
    VERSION 1.0.0
)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD $CPP_STANDARD)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 设置编译选项（可选，根据需求调整）
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# 包含目录
include_directories(
    \${PROJECT_SOURCE_DIR}/include
    \${PROJECT_SOURCE_DIR}/lib/include
)

# 【关键修改1：收集核心源码（排除 src/test 目录，避免测试代码进入核心库）】
file(GLOB_RECURSE CORE_SRC_FILES
    \${PROJECT_SOURCE_DIR}/src/*.cpp
    LIST_DIRECTORIES false
    PATTERN "\${PROJECT_SOURCE_DIR}/src/test/*" EXCLUDE
)

# 【关键修改2：封装核心静态库（STATIC），也可改为 SHARED 生成共享库】
add_library(\${PROJECT_NAME}_core STATIC \${CORE_SRC_FILES})

# 【关键修改3：生成主可执行文件，链接核心静态库】
file(GLOB MAIN_SRC_FILE \${PROJECT_SOURCE_DIR}/src/main.cpp)
add_executable(\${PROJECT_NAME} \${MAIN_SRC_FILE})
target_link_libraries(\${PROJECT_NAME} PRIVATE \${PROJECT_NAME}_core)

# 链接第三方库（可选，后续添加）
# target_link_libraries(\${PROJECT_NAME}_core PRIVATE xxx)

# 子目录：测试模块
add_subdirectory(test)
EOF

# 2. 根目录 README.md（更新：补充核心库相关说明）
cat > "$PROJECT_ROOT/README.md" << EOF
# $PROJECT_NAME

$DESCRIPTION

## 项目信息
- 作者：$AUTHOR
- C++ 标准：C++$CPP_STANDARD
- 构建工具：CMake
- 项目架构：核心代码封装为静态库（\${PROJECT_NAME}_core），主程序/测试程序链接该库

## 目录结构
\`\`\`
$PROJECT_NAME/
├── assets       # 资源文件（图片、配置等）
├── build        # 构建目录（编译产物存放：库文件+可执行文件）
├── cmake        # CMake 辅助配置文件
├── docs         # 项目文档
├── examples     # 示例代码
├── include      # 公共头文件目录
│   └── $PROJECT_NAME  # 项目专属头文件
├── lib          # 第三方库（头文件+预编译库）
│   ├── include
│   └── lib
├── src          # 核心源码目录
│   └── test     # 单元测试源码
├── test         # 测试模块构建配置
└── third_party  # 第三方源码依赖
\`\`\`

## 构建步骤
1. 进入项目根目录
\`\`\`bash
cd $PROJECT_NAME
\`\`\`

2. 进入build目录，执行CMake配置
\`\`\`bash
cd build && cmake ..
\`\`\`

3. 编译项目
\`\`\`bash
make -j\$(nproc)
\`\`\`

4. 运行可执行文件
\`\`\`bash
# 运行主程序
./$PROJECT_NAME

# 运行测试程序（如有）
./$PROJECT_NAME\_test
\`\`\`

## 构建产物说明
编译完成后，build目录下会生成：
- \$PROJECT_NAME：主程序可执行文件
- \$PROJECT_NAME\_core.a：核心静态库文件
- \$PROJECT_NAME\_test：测试程序可执行文件（如有）
EOF

# 3. test 目录 CMakeLists.txt（核心修改：链接核心静态库，而非主可执行文件）
cat > "$PROJECT_ROOT/test/CMakeLists.txt" << EOF
# 测试模块 CMake 配置
cmake_minimum_required(VERSION 3.10)

# 收集测试源文件（后续扩展）
file(GLOB_RECURSE TEST_FILES
    \${PROJECT_SOURCE_DIR}/src/test/*.cpp
)

# 生成测试可执行文件（可选，后续可集成GTest）
if(TEST_FILES)
    add_executable(\${PROJECT_NAME}_test \${TEST_FILES})
    # 【关键修改：链接核心静态库，避免CMake链接报错】
    target_link_libraries(\${PROJECT_NAME}_test PRIVATE \${PROJECT_NAME}_core)
endif()
EOF

# 4. src/main.cpp（保持不变，仅保留基础入口）
cat > "$PROJECT_ROOT/src/main.cpp" << EOF
#include <iostream>
#include "$PROJECT_NAME/$PROJECT_NAME.h"

int main(int argc, char* argv[]) {
    std::cout << "=====================================" << std::endl;
    std::cout << "Welcome to $PROJECT_NAME!" << std::endl;
    std::cout << "C++ Standard: C++$CPP_STANDARD" << std::endl;
    std::cout << "=====================================" << std::endl;

    // 后续业务逻辑编写
    return 0;
}
EOF

# 5. include/$PROJECT_NAME/$PROJECT_NAME.h（项目核心头文件，保持不变）
# 头文件保护宏（转为大写+下划线）
HEADER_GUARD=$(echo "$PROJECT_NAME" | tr 'a-z' 'A-Z')"_H"
cat > "$PROJECT_ROOT/include/$PROJECT_NAME/$PROJECT_NAME.h" << EOF
#ifndef $HEADER_GUARD
#define $HEADER_GUARD

// $PROJECT_NAME 核心头文件
// 作者：$AUTHOR

// 后续添加公共接口、类、宏定义等

#endif // $HEADER_GUARD
EOF

# 6. src/test/${PROJECT_NAME}_test.cpp（测试模板文件，保持不变）
cat > "$PROJECT_ROOT/src/test/${PROJECT_NAME}_test.cpp" << EOF
#include <iostream>
#include "$PROJECT_NAME/$PROJECT_NAME.h"

/**
 * $PROJECT_NAME 单元测试模板
 */
int main(int argc, char* argv[]) {
    std::cout << "Running $PROJECT_NAME tests..." << std::endl;

    // 后续添加测试用例
    return 0;
}
EOF

print_success "基础模板文件生成完成"

# ===================== 结束提示 =====================
print_info "===== 项目生成完成 ====="
print_success "项目路径：$PROJECT_ROOT"
print_info "后续操作建议："
print_info "1. 赋予脚本执行权限（如需再次使用）：chmod +x create_cpp_project.sh"
print_info "2. 进入项目目录：cd $PROJECT_NAME"
print_info "3. 直接构建项目：cd build && cmake .. && make -j\$(nproc)"
print_info "4. 按需补充 third_party、examples 等目录的内容，核心业务代码写在 src 目录下"
print_info "5. 后续集成GTest时，仅需修改 test/CMakeLists.txt 添加框架依赖即可"

