const path = require('path');

module.exports = {
    entry: {
        main: './src/main'
    },
    output: {
        path: path.resolve(__dirname, 'Scripts'),
        filename: '[name].bundle.js',
    },
    resolve: {
        extensions: ['.ts', '.tsx', '.js', 'jsx']
    },
    module: {
        rules: [{
            test: /\.(ts|js)x?$/,
            loader: 'babel-loader',
            exclude: /node_modules/
        }],
    },
    plugins: [
    ],
    externals: {
        react: 'React'
    }
};
